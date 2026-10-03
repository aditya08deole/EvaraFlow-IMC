/** Minimal Request/Response doubles — just enough surface for the ingest/proxy handlers. */
import type { Request, Response } from "express";

export function fakeReq(opts: {
  body?: unknown;
  headers?: Record<string, string>;
  params?: Record<string, string>;
}): Request {
  const headers = opts.headers ?? {};
  return {
    body: opts.body,
    params: opts.params ?? {},
    get(name: string) {
      return headers[name] ?? headers[name.toLowerCase()];
    },
  } as unknown as Request;
}

export function fakeRes(): Response & {
  statusCode: number;
  body: unknown;
  headers: Record<string, string>;
} {
  const res = {
    statusCode: 200,
    body: undefined as unknown,
    headers: {} as Record<string, string>,
    status(code: number) {
      res.statusCode = code;
      return res;
    },
    send(payload: unknown) {
      res.body = payload;
      return res;
    },
    sendStatus(code: number) {
      res.statusCode = code;
      return res;
    },
    set(name: string, value: string) {
      res.headers[name] = value;
      return res;
    },
  };
  return res as unknown as Response & {
    statusCode: number;
    body: unknown;
    headers: Record<string, string>;
  };
}
