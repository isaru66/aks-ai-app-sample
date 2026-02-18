"""
MCP (Model Context Protocol) Service
Connects to MCP servers via streamable-http transport, discovers tools,
and executes tool calls on behalf of the Azure OpenAI model.

Protocol reference: https://spec.modelcontextprotocol.io/specification/
Streamable-HTTP transport uses standard HTTP POST requests with optional
streaming SSE responses.
"""

import json
import asyncio
from typing import Any, AsyncGenerator, Dict, List, Optional
import httpx

from app.core.logging import get_logger
from app.models.schemas import MCPServerConfig, MCPTransport, StreamChunk, StreamChunkType

logger = get_logger(__name__)

# ──────────────────────────────────────────────
# Low-level MCP JSON-RPC helpers
# ──────────────────────────────────────────────

_rpc_id = 0


def _next_id() -> int:
    global _rpc_id
    _rpc_id += 1
    return _rpc_id


def _jsonrpc(method: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    body: Dict[str, Any] = {
        "jsonrpc": "2.0",
        "id": _next_id(),
        "method": method,
    }
    if params is not None:
        body["params"] = params
    return body


def _headers(api_key: Optional[str] = None) -> Dict[str, str]:
    h = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
        "MCP-Protocol-Version": "2025-03-26",
    }
    if api_key:
        h["Authorization"] = f"Bearer {api_key}"
    return h


# ──────────────────────────────────────────────
# Per-server client
# ──────────────────────────────────────────────


class MCPServerClient:
    """Thin async client for a single MCP server (streamable-http or sse)."""

    def __init__(self, config: MCPServerConfig) -> None:
        self.config = config
        self._http = httpx.AsyncClient(timeout=30.0)
        self._session_id: Optional[str] = None
        self._initialized = False

    # ── lifecycle ──────────────────────────────

    async def initialize(self) -> None:
        """Perform MCP initialize handshake."""
        body = _jsonrpc(
            "initialize",
            {
                "protocolVersion": "2025-03-26",
                "capabilities": {"tools": {}},
                "clientInfo": {"name": "aks-ai-app-backend", "version": "1.0"},
            },
        )
        resp = await self._post(body)
        result = resp.get("result", {})
        logger.info(
            f"MCP initialized: server={self.config.url} "
            f"protocol={result.get('protocolVersion')} "
            f"capabilities={list(result.get('capabilities', {}).keys())}"
        )
        # Send initialized notification (no response expected)
        notify = {
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
        }
        try:
            await self._post_raw(notify)
        except Exception:
            pass  # notification – best effort
        self._initialized = True

    async def aclose(self) -> None:
        await self._http.aclose()

    # ── tool discovery ─────────────────────────

    async def list_tools(self) -> List[Dict[str, Any]]:
        """Return list of tool definitions in OpenAI function-calling format."""
        if not self._initialized:
            await self.initialize()

        body = _jsonrpc("tools/list")
        resp = await self._post(body)
        raw_tools: List[Dict[str, Any]] = resp.get("result", {}).get("tools", [])

        openai_tools = []
        for t in raw_tools:
            openai_tools.append(
                {
                    # Responses API flat tool format (not Chat Completions wrapper)
                    "type": "function",
                    "name": _mcp_tool_name(self.config.url, t["name"]),
                    "description": t.get("description", ""),
                    "parameters": t.get("inputSchema", {"type": "object", "properties": {}}),
                    # internal metadata for dispatch — stripped before sending to API
                    "_mcp_url": self.config.url,
                    "_mcp_tool": t["name"],
                }
            )
        logger.info(f"Discovered {len(openai_tools)} tools from {self.config.url}")
        return openai_tools

    # ── tool execution ─────────────────────────

    async def call_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Execute a tool and return the result as a string."""
        if not self._initialized:
            await self.initialize()

        body = _jsonrpc("tools/call", {"name": tool_name, "arguments": arguments})
        resp = await self._post(body)

        result = resp.get("result", {})
        # MCP tools/call result: { content: [{type, text}], isError?: bool }
        if result.get("isError"):
            error_content = _extract_text(result.get("content", []))
            raise RuntimeError(f"MCP tool error from {self.config.url}: {error_content}")

        return _extract_text(result.get("content", []))

    # ── transport ──────────────────────────────

    async def _post(self, body: Dict[str, Any]) -> Dict[str, Any]:
        """POST and return parsed JSON-RPC response (handles SSE wrapping)."""
        raw = await self._post_raw(body)
        if isinstance(raw, dict):
            return raw
        return {}

    async def _post_raw(self, body: Dict[str, Any]) -> Any:
        headers = _headers(self.config.api_key)
        url = self.config.url

        resp = await self._http.post(url, json=body, headers=headers)
        resp.raise_for_status()

        content_type = resp.headers.get("content-type", "")

        if "text/event-stream" in content_type:
            # Streamable HTTP: server may return SSE even for single-response calls
            return _parse_sse_response(resp.text)
        else:
            return resp.json()


# ──────────────────────────────────────────────
# Multi-server orchestrator
# ──────────────────────────────────────────────


class MCPService:
    """
    Orchestrates multiple MCP servers.

    Usage in chat_graph:
        mcp = MCPService(request.mcp_servers or [])
        await mcp.initialize_all()
        tools = await mcp.get_openai_tools()
        # pass tools to Azure OpenAI call
        result = await mcp.execute_tool_call(tool_call)
        await mcp.close_all()
    """

    def __init__(self, configs: List[MCPServerConfig]) -> None:
        self._configs = configs
        self._clients: List[MCPServerClient] = []

    async def initialize_all(self) -> None:
        """Connect and initialize all configured MCP servers concurrently."""
        self._clients = [MCPServerClient(c) for c in self._configs]
        results = await asyncio.gather(
            *[c.initialize() for c in self._clients], return_exceptions=True
        )
        for cfg, result in zip(self._configs, results):
            if isinstance(result, Exception):
                logger.error(f"Failed to initialize MCP server {cfg.url}: {result}")

    async def close_all(self) -> None:
        await asyncio.gather(*[c.aclose() for c in self._clients], return_exceptions=True)
        self._clients = []

    async def get_openai_tools(self) -> List[Dict[str, Any]]:
        """Return merged list of all tools in OpenAI format from all servers."""
        all_tools: List[Dict[str, Any]] = []
        results = await asyncio.gather(
            *[c.list_tools() for c in self._clients], return_exceptions=True
        )
        for cfg, result in zip(self._configs, results):
            if isinstance(result, Exception):
                logger.error(f"Failed to list tools from {cfg.url}: {result}")
            else:
                all_tools.extend(result)
        return all_tools

    async def execute_tool_call(
        self, function_name: str, function_args: Dict[str, Any]
    ) -> str:
        """
        Dispatch a tool call to the correct MCP server.

        function_name is encoded as "<sanitized_url>__<tool_name>" so we can
        reverse-map it to the right server.
        """
        for client in self._clients:
            prefix = _url_to_prefix(client.config.url)
            if function_name.startswith(prefix + "__"):
                tool_name = function_name[len(prefix) + 2 :]
                logger.info(f"Executing MCP tool '{tool_name}' on {client.config.url}")
                return await client.call_tool(tool_name, function_args)

        raise ValueError(f"No MCP server found for tool '{function_name}'")

    # ── context manager ────────────────────────

    async def __aenter__(self) -> "MCPService":
        await self.initialize_all()
        return self

    async def __aexit__(self, *_: Any) -> None:
        await self.close_all()


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────


def _url_to_prefix(url: str) -> str:
    """Create a deterministic, identifier-safe prefix from a URL."""
    import re
    sanitized = re.sub(r"[^a-zA-Z0-9]", "_", url)
    # Limit length to avoid extremely long names
    return sanitized[:40].strip("_")


def _mcp_tool_name(server_url: str, tool_name: str) -> str:
    """Encode server URL + tool name into a single OpenAI function name."""
    return f"{_url_to_prefix(server_url)}__{tool_name}"


def _extract_text(content_items: List[Dict[str, Any]]) -> str:
    """Extract concatenated text from MCP content items."""
    parts = []
    for item in content_items:
        if item.get("type") == "text":
            parts.append(item.get("text", ""))
        elif item.get("type") == "resource":
            resource = item.get("resource", {})
            parts.append(resource.get("text", str(resource)))
        else:
            parts.append(json.dumps(item))
    return "\n".join(parts)


def _parse_sse_response(raw: str) -> Dict[str, Any]:
    """
    Parse the last JSON-RPC response object out of an SSE byte stream.
    MCP streamable-http wraps single responses in SSE for uniformity.
    """
    last: Dict[str, Any] = {}
    for line in raw.splitlines():
        if line.startswith("data:"):
            data = line[5:].strip()
            if data:
                try:
                    last = json.loads(data)
                except json.JSONDecodeError:
                    pass
    return last
