-- Supabase Row-Level Security (RLS) Policies
-- Document: SUPABASE_RLS_POLICIES.md
-- Purpose: Define access control policies for each table based on user roles

# Supabase RLS Policies Implementation Guide

## Overview
This document defines Row-Level Security (RLS) policies for the Pengawasan Kelas application.
RLS ensures users can only access data they are authorized to view/modify based on their role.

## User Roles
- **kepsek** (Kepala Sekolah): Principal - Full access to all data for reporting
- **kemahasiswaan** (Staff Kemahasiswaan): Student affairs staff - Can manage student data
- **guru** (Teacher): Can view/edit own schedules, journals, grades, attendance
- **siswa** (Student): Can view own grades, journals, class info (read-only)

## RLS Implementation Steps

### 1. Enable RLS on All Tables

```sql
-- Run in Supabase SQL Editor
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE guru ENABLE ROW LEVEL SECURITY;
ALTER TABLE siswa ENABLE ROW LEVEL SECURITY;
ALTER TABLE tahun_ajaran ENABLE ROW LEVEL SECURITY;
ALTER TABLE kelas ENABLE ROW LEVEL SECURITY;
ALTER TABLE mapel ENABLE ROW LEVEL SECURITY;
ALTER TABLE jadwal ENABLE ROW LEVEL SECURITY;
ALTER TABLE jurnal ENABLE ROW LEVEL SECURITY;
ALTER TABLE absensi_jurnal ENABLE ROW LEVEL SECURITY;
ALTER TABLE kelas_siswa ENABLE ROW LEVEL SECURITY;
ALTER TABLE nilai ENABLE ROW LEVEL SECURITY;
ALTER TABLE tugas ENABLE ROW LEVEL SECURITY;
ALTER TABLE administrasi_pembelajaran ENABLE ROW LEVEL SECURITY;
ALTER TABLE histori_kelas_siswa ENABLE ROW LEVEL SECURITY;
ALTER TABLE histori_wali_kelas ENABLE ROW LEVEL SECURITY;
```

### 2. Useful Helper Functions

```sql
-- Function to check if user has a specific role
CREATE OR REPLACE FUNCTION user_has_role(user_id UUID, role_name VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = $1
    AND role = $2
    AND is_deleted = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get authenticated user ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RETURN auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3. USERS Table Policies

```sql
-- Anyone authenticated can view all users (necessary for app functionality)
CREATE POLICY "Users can view all profiles" ON users
  FOR SELECT USING (
    auth.uid() IS NOT NULL
  );

-- Users can update own profile only
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (
    auth.uid() = id
  );

-- Kepsek can update any user profile
CREATE POLICY "Kepsek can update any user" ON users
  FOR UPDATE USING (
    user_has_role(auth.uid(), 'kepsek')
  );

-- Insert policy (for admin/auth service)
CREATE POLICY "Insert policy for users" ON users
  FOR INSERT WITH CHECK (true);
```

### 4. USER_ROLES Table Policies

```sql
-- All authenticated users can view user roles (for authorization checks)
CREATE POLICY "Users can view all roles" ON user_roles
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND is_deleted = false
  );

-- Only kepsek can modify roles
CREATE POLICY "Kepsek can manage roles" ON user_roles
  FOR ALL USING (
    user_has_role(auth.uid(), 'kepsek')
  );
```

### 5. GURU Table Policies

```sql
-- All authenticated users can view guru data
CREATE POLICY "View guru data" ON guru
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND is_deleted = false
  );

-- Guru can update own data
CREATE POLICY "Guru can update own data" ON guru
  FOR UPDATE USING (
    auth.uid() = user_id
  );

-- Kepsek and kemahasiswaan can update any guru data
CREATE POLICY "Kepsek/Kemahasiswaan can update guru" ON guru
  FOR UPDATE USING (
    user_has_role(auth.uid(), 'kepsek') OR user_has_role(auth.uid(), 'kemahasiswaan')
  );
```

### 6. SISWA Table Policies

```sql
-- All authenticated users can view siswa data
CREATE POLICY "View siswa data" ON siswa
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND is_deleted = false
  );

-- Student can view own data only
CREATE POLICY "Student view own data" ON siswa
  FOR SELECT USING (
    auth.uid() = user_id
  );

-- Kemahasiswaan and kepsek can modify siswa data
CREATE POLICY "Kemahasiswaan can update siswa" ON siswa
  FOR UPDATE USING (
    user_has_role(auth.uid(), 'kemahasiswaan') OR user_has_role(auth.uid(), 'kepsek')
  );
```

### 7. JADWAL (Schedule) Policies

```sql
-- Teachers can view their own schedules
CREATE POLICY "Guru view own schedule" ON jadwal
  FOR SELECT USING (
    auth.uid() = guru_uid OR
    user_has_role(auth.uid(), 'kepsek') OR
    user_has_role(auth.uid(), 'kemahasiswaan')
  )
  AND is_deleted = false;

-- Teachers can update own schedules
CREATE POLICY "Guru update own schedule" ON jadwal
  FOR UPDATE USING (
    auth.uid() = guru_uid
  );

-- Kepsek can modify any schedule
CREATE POLICY "Kepsek modify schedule" ON jadwal
  FOR ALL USING (
    user_has_role(auth.uid(), 'kepsek')
  );
```

### 8. JURNAL (Teaching Journal) Policies

```sql
-- Teachers can view/edit own journals
CREATE POLICY "Guru view own jurnal" ON jurnal
  FOR SELECT USING (
    auth.uid() = guru_uid OR
    user_has_role(auth.uid(), 'kepsek') OR
    user_has_role(auth.uid(), 'kemahasiswaan')
  )
  AND is_deleted = false;

CREATE POLICY "Guru update own jurnal" ON jurnal
  FOR UPDATE USING (
    auth.uid() = guru_uid
  );

CREATE POLICY "Guru insert jurnal" ON jurnal
  FOR INSERT WITH CHECK (
    auth.uid() = guru_uid
  );

-- Kepsek can view all journals for reporting
CREATE POLICY "Kepsek view all jurnal" ON jurnal
  FOR SELECT USING (
    user_has_role(auth.uid(), 'kepsek')
  );
```

### 9. ABSENSI_JURNAL (Attendance) Policies

```sql
-- Teachers can view attendance for their own classes
CREATE POLICY "Guru view attendance for own classes" ON absensi_jurnal
  FOR SELECT USING (
    auth.uid() IN (
      SELECT guru_uid FROM jurnal WHERE jurnal.id = absensi_jurnal.jurnal_id
    ) OR
    user_has_role(auth.uid(), 'kepsek') OR
    user_has_role(auth.uid(), 'kemahasiswaan')
  )
  AND is_deleted = false;

-- Teachers can update attendance for their own classes
CREATE POLICY "Guru update attendance" ON absensi_jurnal
  FOR UPDATE USING (
    auth.uid() IN (
      SELECT guru_uid FROM jurnal WHERE jurnal.id = absensi_jurnal.jurnal_id
    )
  );

-- Students can view own attendance only
CREATE POLICY "Student view own attendance" ON absensi_jurnal
  FOR SELECT USING (
    auth.uid() = siswa_uid
  )
  AND is_deleted = false;
```

### 10. NILAI (Grades) Policies

```sql
-- Teachers can view grades for classes they teach
CREATE POLICY "Guru view nilai for own mapel" ON nilai
  FOR SELECT USING (
    auth.uid() = guru_uid OR
    user_has_role(auth.uid(), 'kepsek')
  )
  AND is_deleted = false;

-- Teachers can update grades they assigned
CREATE POLICY "Guru update nilai" ON nilai
  FOR UPDATE USING (
    auth.uid() = guru_uid
  );

-- Students can view own grades only
CREATE POLICY "Student view own grades" ON nilai
  FOR SELECT USING (
    auth.uid() = siswa_uid
  )
  AND is_deleted = false;

-- Kepsek can view all grades
CREATE POLICY "Kepsek view all grades" ON nilai
  FOR SELECT USING (
    user_has_role(auth.uid(), 'kepsek')
  );
```

### 11. KELAS_SISWA (Class Enrollment) Policies

```sql
-- Authenticated users can view class enrollment
CREATE POLICY "View class enrollment" ON kelas_siswa
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND is_deleted = false
  );

-- Kemahasiswaan and kepsek can manage enrollment
CREATE POLICY "Manage class enrollment" ON kelas_siswa
  FOR ALL USING (
    user_has_role(auth.uid(), 'kemahasiswaan') OR
    user_has_role(auth.uid(), 'kepsek')
  );
```

### 12. ADMINISTRASI_PEMBELAJARAN Policies

```sql
-- Teachers can view/manage own documents
CREATE POLICY "Guru view own documents" ON administrasi_pembelajaran
  FOR SELECT USING (
    auth.uid() = guru_uid OR
    user_has_role(auth.uid(), 'kepsek') OR
    user_has_role(auth.uid(), 'kemahasiswaan')
  )
  AND is_deleted = false;

CREATE POLICY "Guru manage own documents" ON administrasi_pembelajaran
  FOR ALL USING (
    auth.uid() = guru_uid
  );

-- Kepsek can view all documents
CREATE POLICY "Kepsek view all documents" ON administrasi_pembelajaran
  FOR SELECT USING (
    user_has_role(auth.uid(), 'kepsek')
  );
```

## Implementation in Supabase Dashboard

1. **Go to**: Authentication > Policies
2. **Select table** from dropdown
3. **Create new policy** for each rule above
4. **Test policies** using SQL Editor before deployment

## Testing RLS Policies

### Test with Authenticated User
```sql
-- Run as specific user by setting auth.uid()
SET auth.uid() to 'user_uuid_here';
SELECT * FROM jurnal; -- Should only return their journals
```

### Test with Different Roles
```sql
-- Test as guru
SET auth.uid() to 'guru_uuid_here';
SELECT * FROM nilai WHERE guru_uid = auth.uid();

-- Test as student
SET auth.uid() to 'student_uuid_here';
SELECT * FROM nilai WHERE siswa_uid = auth.uid();

-- Test as kepsek
SET auth.uid() to 'kepsek_uuid_here';
SELECT * FROM nilai; -- Should see all
```

## Security Considerations

1. **Auth Dependency**: RLS policies rely on `auth.uid()` being set correctly by Supabase Auth
2. **Soft Deletes**: All queries should filter `is_deleted = false`
3. **Role Checks**: Always verify roles via `user_roles` table (not just headers)
4. **Updates**: Use `WITH CHECK` to prevent unauthorized updates
5. **Cascading**: Foreign key cascades handle data cleanup

## Troubleshooting

### Policy Not Working
- Verify RLS is enabled: `SELECT tablename FROM pg_tables WHERE schemaname = 'public';`
- Check auth.uid() is being set: `SELECT auth.uid();`
- Test with simple SELECT first

### Data Not Visible
- Confirm user has role in `user_roles` table
- Check `is_deleted` flags (soft deletes)
- Verify user_id matches in auth and users table

### Performance Issues
- Add indexes on filtered columns (done in migration)
- Limit policy complexity (avoid recursive role checks)
- Use prepared statements in code

## Next Steps

1. **Implement in Supabase**: Use SQL Editor to create policies
2. **Test with Flutter App**: Run integration tests
3. **Monitor**: Check Supabase logs for policy violations
4. **Iterate**: Adjust policies based on testing feedback
