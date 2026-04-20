import { serve } from 'https://deno.land/std/http/server.ts'

serve(async (req) => {
  const { to, subject, message } = await req.json()

  console.log('Sending email to:', to)

  return new Response(
    JSON.stringify({ success: true }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})