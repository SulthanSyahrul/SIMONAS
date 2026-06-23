double? averageNilai(Iterable<double?> values) {
  final filtered = values.whereType<double>().toList(growable: false);
  if (filtered.isEmpty) {
    return null;
  }
  return filtered.reduce((a, b) => a + b) / filtered.length;
}

double? calculateNilaiAkhirRaport({
  required double? nilaiTugas,
  required double? nilaiUts,
  required double? nilaiUas,
}) {
  if (nilaiTugas == null || nilaiUts == null || nilaiUas == null) {
    return null;
  }
  return (nilaiTugas + nilaiUts + nilaiUas) / 3;
}
