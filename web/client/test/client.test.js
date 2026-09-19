// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

import { describe, test, expect } from "bun:test";
import { MaridClient, NotFoundError, ValidationError, TimeoutError } from "../src/index.js";

describe("@marid/client Unit Tests", () => {
  test("fetchJson parses successful JSON responses", async () => {
    const mockFetch = async (url, opts) => {
      return {
        ok: true,
        status: 200,
        json: async () => ({ id: "123", name: "Homo sapiens" })
      };
    };

    const client = new MaridClient({ baseUrl: "https://api.example.com", fetch: mockFetch });
    const res = await client.fetchJson("/taxa/123");
    expect(res.id).toBe("123");
    expect(res.name).toBe("Homo sapiens");
  });

  test("fetchJson throws RFC 9457 NotFoundError on 404", async () => {
    const mockFetch = async (url, opts) => {
      return {
        ok: false,
        status: 404,
        json: async () => ({
          type: "https://marid.dev/errors/not-found",
          title: "Entity Not Found",
          status: 404,
          detail: "Taxon 999 does not exist"
        })
      };
    };

    const client = new MaridClient({ baseUrl: "https://api.example.com", fetch: mockFetch });
    expect(client.fetchJson("/taxa/999")).rejects.toThrow(NotFoundError);
  });

  test("fetchJson throws ValidationError on 400", async () => {
    const mockFetch = async (url, opts) => {
      return {
        ok: false,
        status: 400,
        json: async () => ({
          type: "https://marid.dev/errors/validation",
          title: "Bad Request",
          status: 400,
          detail: "Field 'name' is required"
        })
      };
    };

    const client = new MaridClient({ baseUrl: "https://api.example.com", fetch: mockFetch });
    expect(client.fetchJson("/taxa", { method: "POST", body: {} })).rejects.toThrow(ValidationError);
  });

  test("Subscription lifecycle and cancel", async () => {
    const ssePayload = "event: marid.taxon.created\nid: 1\ndata: {\"specversion\":\"1.0\",\"id\":\"evt-1\",\"source\":\"/api/v1/taxa\",\"type\":\"marid.taxon.created\",\"time\":\"2026-09-19T10:00:00Z\",\"topic\":\"taxa:all\",\"sequence\":101,\"data\":{\"id\":\"101\",\"name\":\"Pan troglodytes\"}}\n\n";

    const mockFetch = async (url, opts) => {
      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(ssePayload));
        }
      });
      return {
        ok: true,
        status: 200,
        body: stream
      };
    };

    const client = new MaridClient({ baseUrl: "https://api.example.com", fetch: mockFetch });
    let receivedEvent = null;

    const sub = client.subscribe("taxa:all", {
      onEvent: (evt) => {
        receivedEvent = evt;
      }
    });

    // Wait short tick for stream reader
    await new Promise((r) => setTimeout(r, 50));

    expect(receivedEvent).not.toBeNull();
    expect(receivedEvent.sequence).toBe(101);
    expect(receivedEvent.data.name).toBe("Pan troglodytes");

    sub.cancel();
    expect(sub.isClosed).toBe(true);
  });

  test("Reconnection triggers onResyncRequired on resync event", async () => {
    const resyncPayload = "event: resync_required\nid: 2\ndata: {\"type\":\"marid.sync.resync_required\",\"sequence\":200}\n\n";

    const mockFetch = async (url, opts) => {
      const stream = new ReadableStream({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(resyncPayload));
        }
      });
      return {
        ok: true,
        status: 200,
        body: stream
      };
    };

    const client = new MaridClient({ baseUrl: "https://api.example.com", fetch: mockFetch });
    let resynced = false;

    const sub = client.subscribe("taxa:all", {
      onResyncRequired: () => {
        resynced = true;
      }
    });

    await new Promise((r) => setTimeout(r, 50));
    expect(resynced).toBe(true);
    sub.cancel();
  });
});
