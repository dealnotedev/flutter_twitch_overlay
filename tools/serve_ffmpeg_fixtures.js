// Local-only fixture server used by test_ffmpeg.ps1. No external services.
const [root, readyFile] = Deno.args;
const server = Deno.serve({ hostname: "127.0.0.1", port: 0 }, async (request) => {
  const name = decodeURIComponent(new URL(request.url).pathname.slice(1));
  if (!/^[a-zA-Z0-9.-]+$/.test(name) || name.includes("..")) {
    return new Response("Invalid fixture", { status: 400 });
  }
  try {
    const bytes = await Deno.readFile(`${root}/${name}`);
    return new Response(bytes, { headers: { "content-length": String(bytes.length) } });
  } catch {
    return new Response("Missing fixture", { status: 404 });
  }
});
await Deno.writeTextFile(readyFile, String(server.addr.port));
await server.finished;
