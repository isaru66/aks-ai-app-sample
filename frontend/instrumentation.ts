/**
 * Next.js Instrumentation Hook for OpenTelemetry
 * 
 * This file is automatically called by Next.js when the application starts.
 * It sets up OpenTelemetry tracing for the Next.js frontend application.
 * 
 * @see https://nextjs.org/docs/app/building-your-application/optimizing/instrumentation
 */

export async function register() {
  // Only run instrumentation on the server side
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Check if OpenTelemetry is enabled
    const otelEnabled = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || process.env.ENABLE_OTEL_TRACING === 'true';
    
    if (!otelEnabled) {
      console.log('⚠️  OpenTelemetry tracing is disabled. Set OTEL_EXPORTER_OTLP_ENDPOINT to enable.');
      return;
    }

    try {
      // Dynamically import OpenTelemetry modules (only on server)
      const { Resource } = await import('@opentelemetry/resources');
      const { NodeTracerProvider } = await import('@opentelemetry/sdk-trace-node');
      const { BatchSpanProcessor } = await import('@opentelemetry/sdk-trace-base');
      const { OTLPTraceExporter } = await import('@opentelemetry/exporter-trace-otlp-http');

      // Create resource with service identification (using string literals to avoid deprecated constants)
      const resource = new Resource({
        'service.name': process.env.OTEL_SERVICE_NAME || 'ai-app-frontend',
        'service.version': '1.0.0',
        'deployment.environment': process.env.ENVIRONMENT || 'development',
      });

      console.log('🎯 OpenTelemetry resource:', {
        service: resource.attributes['service.name'],
        version: resource.attributes['service.version'],
        environment: resource.attributes['deployment.environment'],
      });

      // Create tracer provider
      const provider = new NodeTracerProvider({
        resource,
      });

      // Create OTLP exporter (sends to Jaeger)
      const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces';
      
      console.log('🔍 Configuring OTLP exporter:', otlpEndpoint);

      const exporter = new OTLPTraceExporter({
        url: otlpEndpoint,
        headers: process.env.OTEL_EXPORTER_OTLP_HEADERS 
          ? JSON.parse(process.env.OTEL_EXPORTER_OTLP_HEADERS)
          : {},
      });

      // Add batch span processor
      provider.addSpanProcessor(new BatchSpanProcessor(exporter));

      // Register the provider
      provider.register();

      console.log('✅ OpenTelemetry instrumentation initialized');
      console.log('🔧 Next.js server-side requests will be traced');

      // Note: Next.js doesn't have auto-instrumentation like FastAPI
      // Traces will be created for:
      // - API route handlers (if manually instrumented)
      // - Server components (if manually instrumented)
      // - Middleware (if manually instrumented)

    } catch (error) {
      console.error('❌ Failed to initialize OpenTelemetry:', error);
    }
  }
}
