{.experimental: "strictFuncs".}
import std/unittest
import telemetry/breach
suite "Access profile":
  test "update baseline":
    var p = AccessProfile(userId: "u1", hourlyBaseline: 10.0, sampleCount: 5)
    p.updateBaseline(20)
    check p.sampleCount == 6
    check p.hourlyBaseline > 10.0
  test "anomaly detection":
    let p = AccessProfile(userId: "u1", hourlyBaseline: 10.0, sampleCount: 100)
    let score = computeAnomaly(p, 50.0)
    check isAnomalous(score, 3.0)
  test "normal access":
    let p = AccessProfile(userId: "u1", hourlyBaseline: 10.0, sampleCount: 100)
    let score = computeAnomaly(p, 12.0)
    check not isAnomalous(score, 3.0)
suite "PHI monitor":
  test "add records":
    var log = PhiAccessLog(maxRecords: 100)
    log.addRecord(PhiAccessRecord(userId: "u1", resourceType: "Patient", timestamp: "2024-01-01T10:00:00Z"))
    check log.records.len == 1
  test "off hours":
    check isOffHours("2024-01-01T03:00:00Z")
    check not isOffHours("2024-01-01T10:00:00Z")
    check isOffHours("2024-01-01T22:00:00Z")
  test "count by user":
    var log: PhiAccessLog
    log.addRecord(PhiAccessRecord(userId: "u1", timestamp: "t1"))
    log.addRecord(PhiAccessRecord(userId: "u2", timestamp: "t2"))
    log.addRecord(PhiAccessRecord(userId: "u1", timestamp: "t3"))
    check countByUser(log, "u1") == 2
  test "get off hours access":
    var log: PhiAccessLog
    log.addRecord(PhiAccessRecord(userId: "u1", timestamp: "2024-01-01T03:00:00Z"))
    log.addRecord(PhiAccessRecord(userId: "u1", timestamp: "2024-01-01T10:00:00Z"))
    check getOffHoursAccess(log).len == 1
suite "Alerts":
  test "add and filter alerts":
    var log: AlertLog
    log.addAlert(Alert(id: "1", alertType: AlertType.AnomalousAccess, severity: AlertSeverity.Critical, userId: "u1", message: "spike"))
    log.addAlert(Alert(id: "2", alertType: AlertType.OffHoursAccess, severity: AlertSeverity.Warning, userId: "u2", message: "late"))
    check getActiveAlerts(log, AlertSeverity.Critical).len == 1
    check getActiveAlerts(log, AlertSeverity.Warning).len == 1
