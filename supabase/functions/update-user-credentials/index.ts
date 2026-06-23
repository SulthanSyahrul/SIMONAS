import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// CORS headers for Flutter client access
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle preflight CORS request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Initialize Supabase Admin Client using Service Role Key
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      }
    )

    // 2. Validate Authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Authorization header is missing' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const token = authHeader.replace('Bearer ', '')

    // 3. Retrieve caller session from Supabase
    const { data: { user: caller }, error: authError } = await supabaseAdmin.auth.getUser(token)
    if (authError || !caller) {
      return new Response(JSON.stringify({ error: 'Invalid user session token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 4. Verify caller roles
    const { data: roleRecords, error: roleError } = await supabaseAdmin
      .from('user_roles')
      .select('id, roles(role)')
      .eq('user_id', caller.id)
      .eq('is_deleted', false)

    if (roleError || !roleRecords) {
      return new Response(JSON.stringify({ error: 'Failed to fetch user roles' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const isKepalaSekolah = roleRecords.some((record: any) => record.roles?.role === 'kepala_sekolah')
    const isKesiswaan = roleRecords.some((record: any) => record.roles?.role === 'kesiswaan')

    if (!isKepalaSekolah && !isKesiswaan) {
      return new Response(JSON.stringify({ error: 'Forbidden: Authorized roles only' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 5. Parse request body
    const { targetUserId, email, password } = await req.json()
    if (!targetUserId) {
      return new Response(JSON.stringify({ error: 'targetUserId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // If caller is kesiswaan, verify that the target user is a student (has role 'siswa')
    if (!isKepalaSekolah && isKesiswaan) {
      const { data: targetRoles, error: targetRoleError } = await supabaseAdmin
        .from('user_roles')
        .select('id, roles(role)')
        .eq('user_id', targetUserId)
        .eq('is_deleted', false)

      if (targetRoleError || !targetRoles) {
        return new Response(JSON.stringify({ error: 'Failed to fetch target user roles' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }

      const isTargetSiswa = targetRoles.some((record: any) => record.roles?.role === 'siswa')
      if (!isTargetSiswa) {
        return new Response(JSON.stringify({ error: 'Forbidden: BK can only update student credentials' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
    }

    // Build update payload
    const updateAttributes: any = {}
    if (email && email.trim() !== '') {
      updateAttributes.email = email.trim()
    }
    if (password && password.trim() !== '') {
      updateAttributes.password = password.trim()
    }

    if (Object.keys(updateAttributes).length === 0) {
      return new Response(JSON.stringify({ message: 'No credentials to update' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 6. Execute update on target user auth record
    const { data: updatedUser, error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
      targetUserId,
      updateAttributes
    )

    if (updateError) {
      return new Response(JSON.stringify({ error: `Failed to update auth: ${updateError.message}` }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(
      JSON.stringify({
        message: 'Credentials updated successfully',
        user: { id: updatedUser.user.id, email: updatedUser.user.email }
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
