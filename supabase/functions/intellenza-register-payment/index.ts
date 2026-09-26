import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://intellenza-2k26.vercel.app",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const origin = req.headers.get("origin");
  if (origin && origin !== "https://intellenza-2k26.vercel.app") return json({ error: "Origin not allowed" }, 403);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "Payment submission service is not configured." }, 503);

  let uploadedPath: string | null = null;
  const supabase = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  try {
    const form = await req.formData();
    const full_name = String(form.get("name") ?? "").trim();
    const email = String(form.get("email") ?? "").trim().toLowerCase();
    const phone = String(form.get("phone") ?? "").trim();
    const college = String(form.get("college") ?? "").trim();
    const department = String(form.get("department") ?? "").trim();
    const yearRaw = String(form.get("year") ?? "").trim();
    const event_name = String(form.get("event") ?? "").trim();
    const packageName = String(form.get("package") ?? "").trim();
    const utr = String(form.get("utr") ?? "").trim();
    const proof = form.get("paymentProof");

    const years = ["", "1st Year", "2nd Year", "3rd Year", "4th Year", "Other"];
    const events = ["SLIDEVERSE · Paper Presentation", "CODEBREACH · Debugging", "PROMPTIX · Prompt Creation", "HUNTOPIA 2.0 · Treasure Hunt", "BOOYAH ARENA · Free Fire", "MEMORIA · Memory Challenge"];
    const fees: Record<string, number> = { "Symposium - ₹250": 250, "Workshop - ₹200": 200, "Both days - ₹400": 400 };
    if (full_name.length < 2 || full_name.length > 120 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 ||
        phone.length < 10 || phone.length > 20 || college.length < 2 || college.length > 180 ||
        department.length < 2 || department.length > 120 || !years.includes(yearRaw) ||
        !events.includes(event_name) || !(packageName in fees) || utr.length < 6 || utr.length > 100) {
      return json({ error: "Please check all registration details and the selected pass." }, 400);
    }
    if (!(proof instanceof File)) return json({ error: "Payment screenshot or receipt is required." }, 400);
    const allowed = ["image/jpeg", "image/png", "image/webp", "application/pdf"];
    if (!allowed.includes(proof.type) || proof.size < 1 || proof.size > 5 * 1024 * 1024) {
      return json({ error: "Proof must be JPG, PNG, WEBP or PDF, up to 5 MB." }, 400);
    }

    const registrationId = crypto.randomUUID();
    const ext = ({ "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "application/pdf": "pdf" } as Record<string,string>)[proof.type];
    uploadedPath = `${registrationId}/${crypto.randomUUID()}.${ext}`;
    const bytes = new Uint8Array(await proof.arrayBuffer());
    const { error: uploadError } = await supabase.storage.from("intellenza-payment-proofs")
      .upload(uploadedPath, bytes, { contentType: proof.type, upsert: false });
    if (uploadError) throw uploadError;

    const { error: insertError } = await supabase.from("registrations").insert({
      id: registrationId, full_name, email, phone, college, department,
      year_of_study: yearRaw || null, event_name, package: packageName, utr,
      payment_status: "pending", payment_screenshot_path: uploadedPath,
    });
    if (insertError) throw insertError;
    return json({ ok: true, registrationId, paymentStatus: "pending" }, 201);
  } catch (error) {
    if (uploadedPath) await supabase.storage.from("intellenza-payment-proofs").remove([uploadedPath]).catch(() => {});
    console.error("Registration payment submission failed:", error);
    return json({ error: "Submission could not be completed. Check the UTR and try again." }, 400);
  }
});