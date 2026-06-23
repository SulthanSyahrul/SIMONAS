-- ============================================================================
-- ADD FILE PATH COLUMN TO ADMINISTRASI_PEMBELAJARAN
-- Purpose: store Supabase Storage object path for uploaded documents
-- ============================================================================

ALTER TABLE public.administrasi_pembelajaran
ADD COLUMN IF NOT EXISTS file_path TEXT;

CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_file_path
ON public.administrasi_pembelajaran(file_path)
WHERE file_path IS NOT NULL AND is_deleted = false;
