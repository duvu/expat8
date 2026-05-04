export function loadConfig(env = process.env) {
  return {
    port: Number.parseInt(env.PORT ?? '8787', 10),
    liteLLMBaseUrl: env.LITELLM_BASE_URL ?? 'http://localhost:4000',
    liteLLMApiKey: env.LITELLM_API_KEY ?? '',
    liteLLMModel: env.LITELLM_MODEL ?? 'gpt-4o-mini',
    defaultSourceLanguage: env.DEFAULT_SOURCE_LANGUAGE ?? 'vi',
    defaultTargetLanguage: env.DEFAULT_TARGET_LANGUAGE ?? 'en',
    newWordTimeoutSeconds: Number.parseInt(env.NEW_WORD_TIMEOUT_SECONDS ?? '5', 10)
  };
}
