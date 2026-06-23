-- ============================================================================
-- STORAGE SETUP & RLS POLICIES
-- Purpose: configure storage bucket and object policies for administrasi docs
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('administrasi_pembelajaran', 'administrasi_pembelajaran', false)
ON CONFLICT (id) DO NOTHING;

-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Administrasi upload own docs" ON storage.objects;
CREATE POLICY "Administrasi upload own docs" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'administrasi_pembelajaran' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Administrasi read own docs" ON storage.objects;
CREATE POLICY "Administrasi read own docs" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'administrasi_pembelajaran' AND
    (
      auth.uid()::text = (storage.foldername(name))[1] OR
      EXISTS (
        SELECT 1
        FROM public.user_roles ur
        JOIN public.roles r ON ur.role_id = r.id
        WHERE ur.user_id = auth.uid()
          AND r.role IN ('kepala_sekolah', 'kesiswaan', 'kepsek', 'kemahasiswaan')
          AND ur.is_deleted = false
      )
    )
  );

DROP POLICY IF EXISTS "Administrasi delete own docs" ON storage.objects;
CREATE POLICY "Administrasi delete own docs" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'administrasi_pembelajaran' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
