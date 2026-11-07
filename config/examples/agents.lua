-- The CockPit: extra AI / CLI agent profiles.
-- The menu already detects grok, claude, codex, cursor-agent and gemini when you have
-- installed them. Add anything else here. Each tool uses its own login; The CockPit
-- never signs in, stores tokens, or sends text anywhere by itself.
return {
  -- { label = "Ollama llama3.1", argv = { "ollama", "run", "llama3.1:8b" } },
  -- { label = "Aider in ~/code", argv = { "aider" }, cwd = "~/code" },
}
