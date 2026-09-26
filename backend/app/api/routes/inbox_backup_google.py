from html import escape

from fastapi import APIRouter, Query
from fastapi.responses import HTMLResponse

router = APIRouter(prefix="/inbox/backup/google", tags=["Inbox Backup Google OAuth"])


@router.get("/callback", response_class=HTMLResponse)
def google_drive_backup_callback(
    code: str | None = Query(default=None),
    state: str | None = Query(default=None),
    error: str | None = Query(default=None),
):
    """Receive the Google Drive OAuth redirect for Inbox chat backup.

    The mobile/web client starts OAuth from /inbox/backup/google/authorize.
    Google redirects the browser here with an authorization code. Because this
    browser redirect does not include the app's bearer token, this callback does
    not connect the Drive account directly. Instead, it displays the code so the
    app/tester can send it to POST /inbox/backup/google/connect from an
    authenticated session.
    """

    if error:
        safe_error = escape(error)
        return HTMLResponse(
            content=f"""
            <!doctype html>
            <html>
              <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <title>FunKey Inbox Backup</title>
                <style>
                  body {{ font-family: Arial, sans-serif; background: #faf7f1; color: #251538; padding: 28px; }}
                  .card {{ max-width: 680px; margin: auto; background: white; border-radius: 24px; padding: 24px; box-shadow: 0 14px 36px rgba(37, 21, 56, 0.12); }}
                  h1 {{ margin: 0 0 10px; font-size: 24px; }}
                  .error {{ background: #fff1f2; color: #be123c; border-radius: 14px; padding: 12px; font-weight: 700; }}
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>Google Drive backup authorization failed</h1>
                  <p class="error">{safe_error}</p>
                  <p>Return to FunKey and try connecting Google Drive again.</p>
                </div>
              </body>
            </html>
            """
        )

    if not code:
        return HTMLResponse(
            content="""
            <!doctype html>
            <html>
              <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <title>FunKey Inbox Backup</title>
                <style>
                  body { font-family: Arial, sans-serif; background: #faf7f1; color: #251538; padding: 28px; }
                  .card { max-width: 680px; margin: auto; background: white; border-radius: 24px; padding: 24px; box-shadow: 0 14px 36px rgba(37, 21, 56, 0.12); }
                  h1 { margin: 0 0 10px; font-size: 24px; }
                </style>
              </head>
              <body>
                <div class="card">
                  <h1>No authorization code received</h1>
                  <p>Return to FunKey and start Google Drive backup authorization again.</p>
                </div>
              </body>
            </html>
            """
        )

    safe_code = escape(code)
    safe_state = escape(state or "")
    return HTMLResponse(
        content=f"""
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>FunKey Inbox Backup</title>
            <style>
              body {{ font-family: Arial, sans-serif; background: #faf7f1; color: #251538; padding: 28px; }}
              .card {{ max-width: 760px; margin: auto; background: white; border-radius: 24px; padding: 24px; box-shadow: 0 14px 36px rgba(37, 21, 56, 0.12); }}
              h1 {{ margin: 0 0 10px; font-size: 24px; }}
              p {{ color: #6b5b74; line-height: 1.45; }}
              .code {{ word-break: break-all; background: #f4eef9; border: 1px solid #e5d7ee; border-radius: 16px; padding: 14px; font-family: Consolas, monospace; font-size: 13px; color: #251538; }}
              .state {{ word-break: break-all; color: #7b6a86; font-size: 12px; }}
              .ok {{ display: inline-block; background: #12c7b7; color: white; padding: 8px 12px; border-radius: 999px; font-weight: 800; font-size: 12px; }}
            </style>
          </head>
          <body>
            <div class="card">
              <span class="ok">Authorization code received</span>
              <h1>Connect Google Drive backup</h1>
              <p>Copy this authorization code into the FunKey Inbox backup setup screen, or send it from backend testing to <strong>POST /inbox/backup/google/connect</strong> while logged in.</p>
              <div class="code">{safe_code}</div>
              <p class="state">State: {safe_state}</p>
              <p>After connecting, Inbox backup can upload encrypted chat backup files to the user's Google Drive app folder.</p>
            </div>
          </body>
        </html>
        """
    )
