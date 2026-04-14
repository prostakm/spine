# Feature: auth-session

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/auth-session/spec.md`

**Goal:** Session-based auth — login, logout, middleware. Server-side sessions in SQLite, httpOnly cookie.

**Approach:** Sessions table + random token cookie. Server-side over JWT because sessions are instantly revocable and don't bloat cookies.

| Alternative | Why rejected |
|---|---|
| JWT in httpOnly cookie | Can't revoke without blocklist |
| JWT + refresh token | Over-engineered for single-app |
| External OAuth | Violates single-binary constraint |

**Risks:**
- Session table unbounded growth → hourly cleanup goroutine, indexed `expires_at`
- Per-request DB lookup → benchmark must confirm <5ms at 10k sessions

---

### Phase 1: Session storage

`migrations/002_sessions.sql` — create
```sql
CREATE TABLE sessions (
    token      TEXT PRIMARY KEY,  -- crypto/rand 32 bytes, hex
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
CREATE INDEX idx_sessions_user ON sessions(user_id);
```

`internal/auth/session_repo.go` — create
```go
type Session struct { Token string; UserID int64; ExpiresAt, CreatedAt time.Time }
type SessionRepo struct { db *sql.DB }

func (r *SessionRepo) Create(ctx, userID, ttl) (Session, error)
  // crypto/rand 32 bytes → hex token, INSERT with expires_at = now+ttl

func (r *SessionRepo) FindByToken(ctx, token) (Session, error)
  // SELECT WHERE token=? AND expires_at > now; ErrSessionNotFound if miss

func (r *SessionRepo) Delete(ctx, token) error
func (r *SessionRepo) DeleteByUser(ctx, userID) error  // logout-everywhere
func (r *SessionRepo) CleanExpired(ctx) (int64, error)  // returns rows deleted
```

Tests — `session_repo_test.go`:
- create and find valid session
- find expired session → ErrSessionNotFound
- delete removes session
- delete by user clears all user sessions

**Verify:** `go test ./internal/auth/... -run TestSessionRepo`
**Status:** pending

---

### Phase 2: Login & logout handlers

`internal/auth/handler.go` — create
```go
type AuthHandler struct { sessions *SessionRepo; users *UserRepo; ttl time.Duration }

// POST /login — {"email", "password"}
// → 200 + Set-Cookie(session=token; HttpOnly; Secure; SameSite=Strict)
// → 401 "invalid credentials" (same msg for bad email AND bad password)
func (h *AuthHandler) Login(w, r)
  // parse body → FindByEmail → bcrypt.Compare → sessions.Create → setCookie

// POST /logout — requires session cookie
// → 200 + clear cookie
func (h *AuthHandler) Logout(w, r)
  // get cookie → sessions.Delete → clear cookie (MaxAge=-1)
```

`internal/api/routes.go` — modify — register /login, /logout

Edge cases:
- No user enumeration: same 401 for bad email and bad password
- Cookie flags: httpOnly + Secure + SameSite=Strict
- Reject non-JSON with 415

Tests — `handler_test.go`:
- valid login → 200 + cookie
- wrong password → 401, no cookie
- unknown email → 401, same message (no enumeration)
- missing fields → 400
- logout clears session and cookie
- logout without cookie → 401

**Verify:** `go test ./internal/auth/... -run TestHandler`
**Status:** pending

---

### Phase 3: Session middleware

`internal/auth/context.go` — create
```go
func ContextWithUser(ctx, *User) context.Context
func UserFromContext(ctx) (*User, bool)  // nil,false if missing
```

`internal/auth/middleware.go` — create
```go
func RequireAuth(sessions, users) func(http.Handler) http.Handler
  // get cookie → FindByToken → FindByID → inject user into ctx → next
  // missing/expired/orphaned → 401 + clear cookie
```

`internal/api/routes.go` — modify — wrap protected routes

Tests — `middleware_test.go`:
- valid session → passes through, user in context
- missing cookie → 401
- expired session → 401 + cookie cleared
- session with deleted user → 401 + session cleaned up

**Verify:** `go test ./internal/auth/... -run TestMiddleware`
**Status:** pending

---

### Phase 4: Cleanup + integration test

`internal/auth/cleanup.go` — create
```go
func StartCleanup(ctx, repo, interval)
  // ticker loop: repo.CleanExpired every interval
  // stops on ctx.Done (server shutdown)
```

`cmd/server/main.go` — modify — start cleanup goroutine

`internal/auth/integration_test.go` — create
- full flow: login → access protected → logout → access denied
- benchmark: FindByToken with 10k sessions < 5ms p99

**Verify:** `go test ./internal/auth/... -count=1` + benchmark
**Status:** pending

---

## Review Gate
- Status: pending

## State
- Phase: planning

## Decisions
| Decision | Date | Rationale |
|----------|------|-----------|

## Errors
| Error | Attempt | Resolution |
|-------|---------|------------|

<!-- REVIEW: PENDING — add comments inline with > [R]: your comment -->
  // get cookie → sessions.Delete → clear cookie (MaxAge=-1)
```

`internal/api/routes.go` — modify — register /login, /logout

Edge cases:
- No user enumeration: same 401 for bad email and bad password
- Cookie flags: httpOnly + Secure + SameSite=Strict
- Reject non-JSON with 415

Tests — `handler_test.go`:
- valid login → 200 + cookie
- wrong password → 401, no cookie
- unknown email → 401, same message (no enumeration)
- missing fields → 400
- logout clears session and cookie
- logout without cookie → 401

**Verify:** `go test ./internal/auth/... -run TestHandler`
**Status:** pending

---

### Phase 3: Session middleware

`internal/auth/context.go` — create
```go
func ContextWithUser(ctx, *User) context.Context
func UserFromContext(ctx) (*User, bool)  // nil,false if missing
```

`internal/auth/middleware.go` — create
```go
func RequireAuth(sessions, users) func(http.Handler) http.Handler
  // get cookie → FindByToken → FindByID → inject user into ctx → next
  // missing/expired/orphaned → 401 + clear cookie
```

`internal/api/routes.go` — modify — wrap protected routes

Tests — `middleware_test.go`:
- valid session → passes through, user in context
- missing cookie → 401
- expired session → 401 + cookie cleared
- session with deleted user → 401 + session cleaned up

**Verify:** `go test ./internal/auth/... -run TestMiddleware`
**Status:** pending

---

### Phase 4: Cleanup + integration test

`internal/auth/cleanup.go` — create
```go
func StartCleanup(ctx, repo, interval)
  // ticker loop: repo.CleanExpired every interval
  // stops on ctx.Done (server shutdown)
```

`cmd/server/main.go` — modify — start cleanup goroutine

`internal/auth/integration_test.go` — create
- full flow: login → access protected → logout → access denied
- benchmark: FindByToken with 10k sessions < 5ms p99

**Verify:** `go test ./internal/auth/... -count=1` + benchmark
**Status:** pending

---

## Review Gate
- Status: pending

## State
- Phase: planning

## Decisions
| Decision | Date | Rationale |
|----------|------|-----------|

## Errors
| Error | Attempt | Resolution |
|-------|---------|------------|

<!-- REVIEW: PENDING — add comments inline with > [R]: your comment -->
