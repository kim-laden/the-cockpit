-- The CockPit: your SSH connections.
-- Each entry appears in the menu (right-click / F12) and connects ONLY when you pick it.
-- No keys or passwords belong here: authenticate with your own SSH agent/keys/password
-- at connect time, and verify a new server's host key fingerprint out-of-band.
-- Agent forwarding and X11 forwarding are always disabled for these entries.
--
-- Two styles:
--   { label = "Name", host = "server.example.com", user = "me", port = 22 }
--   { label = "Name", alias = "myserver" }   -- uses Host myserver from ~/.ssh/config
return {
  -- { label = "My VPS",  host = "vps.example.com", user = "me", port = 22 },
  -- { label = "Homelab", alias = "homelab" },
}
