#!/usr/bin/env python3
"""End-to-end streaming test for the AgakAI chat edge function.

Sends a request to POST /functions/v1/chat with stream:true and verifies the
SSE pipeline:  transcript → delta* → audio* → done, with timing metrics so
you can see whether audio starts BEFORE the LLM finishes generating.

Usage:
  python3 scripts/test_stream.py                        # default text question
  python3 scripts/test_stream.py --text "Ano ang pension?"
  python3 scripts/test_stream.py --audio rec.m4a --format m4a   # STT path
  python3 scripts/test_stream.py --loop                 # round trip:
                                                        #   synthesize voice via /tts
                                                        #   → feed it back as STT input
  python3 scripts/test_stream.py --out /tmp/reply.mp3   # save the spoken answer

Config is read from .env (SUPABASE_URL, SUPABASE_ANON_KEY) or the environment.
Exit code 0 = all checks passed, 1 = failure.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env():
    env = {}
    envfile = os.path.join(ROOT, ".env")
    if os.path.exists(envfile):
        for line in open(envfile):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    url = os.environ.get("SUPABASE_URL") or env.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_ANON_KEY") or env.get("SUPABASE_ANON_KEY")
    if not url or not key:
        sys.exit("Missing SUPABASE_URL / SUPABASE_ANON_KEY (set env or .env)")
    return url.rstrip("/"), key


def post_json(url, key, payload):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
            "apikey": key,
        },
        method="POST",
    )
    return urllib.request.urlopen(req, timeout=180)


def synthesize_speech(url, key, text):
    """Use the deployed tts function to create a spoken sample for STT input."""
    print(f"  synthesizing voice sample via /tts: {text!r}")
    t0 = time.monotonic()
    resp = post_json(f"{url}/functions/v1/tts", key, {"text": text})
    mp3 = resp.read()
    print(f"  got {len(mp3)} bytes in {time.monotonic() - t0:.2f}s")
    return mp3


def parse_sse(resp):
    """Yield (event_name, data_dict) from an SSE response stream."""
    event = None
    for raw in resp:
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        if line.startswith("event: "):
            event = line[7:].strip()
        elif line.startswith("data: ") and event is not None:
            try:
                yield event, json.loads(line[6:])
            except json.JSONDecodeError:
                yield event, {"_raw": line[6:]}
            event = None


def run_chat_test(url, key, payload, out_path=None):
    t_start = time.monotonic()

    def ts():
        return time.monotonic() - t_start

    print(f"→ POST {url}/functions/v1/chat  stream:true")
    resp = post_json(f"{url}/functions/v1/chat", key, payload)
    ctype = resp.headers.get("Content-Type", "")
    if "text/event-stream" not in ctype:
        print(f"✗ expected text/event-stream, got: {ctype}")
        print(resp.read().decode(errors="replace")[:500])
        return False
    print(f"  SSE connection open ({ctype})")

    first, last, count = {}, {}, {}
    answer, transcript = [], []
    audio_bytes = bytearray()
    error_msg = None
    done_answer = None

    for event, data in parse_sse(resp):
        now = ts()
        first.setdefault(event, now)
        last[event] = now
        count[event] = count.get(event, 0) + 1

        if event == "transcript":
            transcript.append(data.get("question", ""))
            print(f"  [{now:6.2f}s] transcript: {data.get('question')!r}")
        elif event == "delta":
            answer.append(data.get("text", ""))
            if count["delta"] == 1:
                print(f"  [{now:6.2f}s] first delta: {data.get('text')!r} …")
        elif event == "audio":
            audio_bytes += base64.b64decode(data.get("chunk_base64", ""))
            if count["audio"] == 1:
                print(f"  [{now:6.2f}s] first audio chunk 🎧")
        elif event == "done":
            done_answer = data.get("answer", "")
            print(f"  [{now:6.2f}s] done")
        elif event == "error":
            error_msg = data.get("message", str(data))
            print(f"  [{now:6.2f}s] ERROR: {error_msg}")

    total = ts()
    answer_text = "".join(answer)

    # ---- report ----
    print("\n— metrics —")
    for ev in ("transcript", "delta", "audio", "done"):
        if ev in first:
            print(f"  {ev:<10} first={first[ev]:6.2f}s  last={last[ev]:6.2f}s  n={count.get(ev, 0)}")
    print(f"  total      {total:6.2f}s")
    if "transcript" in first and "delta" in first:
        print(f"  LLM first-token latency: {first['delta'] - first['transcript']:.2f}s")
    if "delta" in first and "audio" in first:
        ttfa = first["audio"] - first["delta"]
        print(f"  voice after first token: {ttfa:.2f}s")
    if "delta" in last and "audio" in first:
        interleave = last["delta"] - first["audio"]
        if interleave > 0:
            print(f"  ✅ interleaved: voice started {interleave:.2f}s BEFORE the LLM finished")
        else:
            print(f"  ⚠ no overlap: voice started {-interleave:.2f}s after the LLM finished")
    print(f"  answer: {(done_answer or answer_text)[:120]!r}…")

    if out_path and audio_bytes:
        open(out_path, "wb").write(audio_bytes)
        print(f"  💾 wrote {len(audio_bytes)} bytes → {out_path}  (play: ffplay {out_path})")

    # ---- checks ----
    print("\n— checks —")
    checks = [
        ("no error event", error_msg is None),
        ("got transcript", "transcript" in first),
        ("got deltas", count.get("delta", 0) > 0),
        ("got audio chunks", count.get("audio", 0) > 0),
        ("got done", "done" in first),
        ("answer non-empty", bool((done_answer or answer_text).strip())),
        ("delta text matches done answer", done_answer is None or answer_text == done_answer),
    ]
    ok = True
    for name, passed in checks:
        print(f"  {'✅' if passed else '✗'} {name}")
        ok &= passed
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--text", help="text question (skips STT)")
    ap.add_argument("--audio", help="audio file to send as STT input")
    ap.add_argument("--format", default="m4a", help="audio format of --audio (default m4a)")
    ap.add_argument(
        "--loop",
        action="store_true",
        help="round-trip test: synthesize voice via /tts, send it as STT input",
    )
    ap.add_argument("--loop-phrase", default="Ano ang mga benepisyo para sa mga senior citizen?")
    ap.add_argument("--out", help="save the spoken reply as mp3")
    ap.add_argument("--history", help='JSON history, e.g. \'[{"role":"user","content":"hi"},{"role":"assistant","content":"hello"}]\'')
    args = ap.parse_args()

    url, key = load_env()
    payload = {"stream": True}
    if args.history:
        payload["history"] = json.loads(args.history)

    if args.loop:
        payload["audio_data"] = base64.b64encode(
            synthesize_speech(url, key, args.loop_phrase)
        ).decode()
        payload["audio_format"] = "mp3"
        print(f"→ STT round trip: phrase {args.loop_phrase!r} spoken by TTS voice")
    elif args.audio:
        payload["audio_data"] = base64.b64encode(open(args.audio, "rb").read()).decode()
        payload["audio_format"] = args.format
    else:
        payload["text"] = args.text or "What benefits can senior citizens in Dumaguete get?"

    ok = run_chat_test(url, key, payload, args.out)
    print(f"\n{'✅ PASS' if ok else '✗ FAIL'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
