Tech Stack: Flutter, Riverpod, go_router, sqflite (SQLite)

Rules:
- Match reference screenshots exactly — no layout redesign
- Only color change: #21273e -> #9CC70A, #438aee -> #414A51 — nothing else changes
- Every feature has: repository interface + sqlite implementation + firebase stub (empty for now)
- UI/screens only depend on the repository interface, never SQLite or Firebase directly
- No raw SQL inside widgets — only inside sqlite repository files
- To switch to Firebase later: fill in the firebase repository file, change one provider line — no screen files touched
- Read this file before making any changes