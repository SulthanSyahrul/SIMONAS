-- ============================================================================
-- ADD VERIFICATION COLUMNS TO ADMINISTRASI_PEMBELAJARAN
-- Purpose: allow kepala sekolah to review and update administrasi pembelajaran
-- ============================================================================

ALTER TABLE public.administrasi_pembelajaran
ADD COLUMN IF NOT EXISTS status_verifikasi TEXT NOT NULL DEFAULT 'menunggu',
ADD COLUMN IF NOT EXISTS catatan_verifikasi TEXT;

CREATE INDEX IF NOT EXISTS idx_adm_pembelajaran_status_verifikasi
ON public.administrasi_pembelajaran(status_verifikasi)
WHERE is_deleted = false;
