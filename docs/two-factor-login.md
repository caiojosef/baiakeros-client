# Two-factor login

The production website already owns authenticator enrollment, encrypted secrets,
recovery-code hashes, rate limits and game-session tickets. The client does not query
the database or decide which accounts require a second factor.

## Existing production contract

After the account password is verified, `login.php` checks `MyAAC\TwoFactor::state()`.
An enabled account without a code receives JSON `errorCode: 6` and `errorMessage`.
The client opens a modal and submits the code through the existing HTTP login
transport's `token` field. Accounts without 2FA continue to the character list.

The backend accepts six-digit TOTP codes (30-second steps, preserving leading zeroes)
or a recovery code containing 20 hexadecimal digits, optionally separated by hyphens
or spaces. Each recovery code is consumed by the backend. Incorrect, expired, reused
codes and temporary blocking are reported using the server's original message.

On success, the backend returns `session.sessionkey`, including its compact
`@2fa:...\n@session` ticket for enabled accounts. The client passes this ticket through
the existing game login path and discards the submitted code. Neither TOTP codes nor
recovery codes are added to saved-account settings.

The read-only production inspection confirmed these tables:

- `myaac_account_two_factor`: encrypted enrollment, revision and verification/rate-limit state.
- `myaac_two_factor_recovery`: recovery-code hashes.
- `myaac_two_factor_game_sessions`: session hash, account/revision/password binding and expiry.

No private key, enrollment secret, recovery hash or account password was downloaded.
No production database or website changes are needed for this client change.

## Lifecycle and validation

Fresh logins clear any prior code/ticket; retrying the challenge preserves its account
context. Changing the account, password, host, port or protocol cancels that challenge.
Unique request IDs reject delayed HTTP responses after retry/cancellation. The modal
blocks input to the login form and remains on top of delayed startup UI callbacks.
The dialog uses a compact 300x150 layout. The initial required-code message does not
repeat the instructions; validation errors expand its height to fit wrapped text.

`tests/native/two_factor_login.lua` runs the real client UI with a mocked login
transport and synthetic credentials. It covers normal login, required 2FA, TOTP with
a leading zero, invalid format, recovery codes, server blocking/reuse messages,
successful session-ticket handling, cancel, stale replies, credential changes and
modal layout. It does not sign into a real production account or consume real codes.

Only Lua/OTUI files changed; no native binary rebuild or asset-path changes are required.
Publishing a public updater revision remains a separate release step.
