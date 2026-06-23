-- Calculates a student's final report score for one class, subject, and
-- academic year. Returns NULL until assignment average, UTS, and UAS exist.

CREATE OR REPLACE FUNCTION public.hitung_nilai_akhir_siswa_raport(
  p_siswa_uid integer,
  p_kelas_id integer,
  p_mapel_id integer,
  p_tahun_ajaran_id integer,
  p_semester_ke integer DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_nilai_uts numeric;
  v_nilai_uas numeric;
  v_rata_rata_tugas numeric;
BEGIN
  SELECT
    nu.nilai_uts,
    nu.nilai_uas
  INTO
    v_nilai_uts,
    v_nilai_uas
  FROM public.nilai_ujian nu
  WHERE nu.siswa_uid = p_siswa_uid
    AND nu.kelas_id = p_kelas_id
    AND nu.mapel_id = p_mapel_id
    AND nu.tahun_ajaran_id = p_tahun_ajaran_id
    AND nu.is_deleted = false
  ORDER BY nu.updated_at DESC
  LIMIT 1;

  SELECT AVG(nt.nilai)
  INTO v_rata_rata_tugas
  FROM public.nilai_tugas nt
  JOIN public.tugas t ON t.id = nt.tugas_id
  JOIN public.semester s ON s.id = t.semester_id
  WHERE nt.siswa_uid = p_siswa_uid
    AND t.kelas_id = p_kelas_id
    AND t.mapel_id = p_mapel_id
    AND s.tahun_ajaran_id = p_tahun_ajaran_id
    AND (p_semester_ke IS NULL OR s.semester_ke = p_semester_ke)
    AND nt.nilai IS NOT NULL
    AND nt.is_deleted = false
    AND t.is_deleted = false
    AND s.is_deleted = false;

  IF v_rata_rata_tugas IS NULL
    OR v_nilai_uts IS NULL
    OR v_nilai_uas IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN ROUND(((v_rata_rata_tugas + v_nilai_uts + v_nilai_uas) / 3)::numeric, 2);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hitung_nilai_akhir_siswa_raport(
  integer,
  integer,
  integer,
  integer,
  integer
) TO authenticated;
