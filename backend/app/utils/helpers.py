from typing import Any, Dict, List
import json
from datetime import datetime


def safe_json_dumps(obj: Any) -> str:
    """
    Safely serialize object to JSON.
    
    Args:
        obj: Object to serialize
    
    Returns:
        JSON string
    """
    try:
        return json.dumps(obj, default=str)
    except Exception:
        return str(obj)


def format_timestamp(dt: datetime) -> str:
    """
    Format datetime as ISO string.
    
    Args:
        dt: Datetime object
    
    Returns:
        ISO formatted string
    """
    return dt.isoformat()


def chunk_text(text: str, chunk_size: int = 1000) -> List[str]:
    """
    Split text into chunks.
    
    Args:
        text: Text to chunk
        chunk_size: Maximum chunk size
    
    Returns:
        List of text chunks
    """
    return [text[i:i+chunk_size] for i in range(0, len(text), chunk_size)]


def merge_thinking_steps(steps: List[Dict[str, Any]]) -> str:
    """
    Merge thinking steps into readable text.
    
    Args:
        steps: List of thinking steps
    
    Returns:
        Merged text
    """
    if not steps:
        return ""
    
    lines = []
    for step in steps:
        step_num = step.get("step_number", 0)
        reasoning = step.get("reasoning", "")
        lines.append(f"Step {step_num}: {reasoning}")
    
    return "\n".join(lines)
