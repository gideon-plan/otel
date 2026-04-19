#[
======
breach
======
Breach detection: access baselines, anomaly scoring, PHI monitoring, alerts.
]#
{.experimental: "strictFuncs".}
import basis/code/throw
standard_pragmas(effects=false, rise=false)
import std/[strutils, math]

type
  AccessProfile* = object
    userId*: string
    hourlyBaseline*: float
    dailyBaseline*: float
    sampleCount*: int
  AnomalyScore* = object
    userId*: string
    score*: float
    hourlyRate*: float
    dailyRate*: float
  BreachConfig* = object
    anomalyThreshold*: float
    cooldownSec*: int
    windowSec*: int
  PhiAccessRecord* = object
    userId*: string
    resourceType*: string
    resourceId*: string
    action*: string
    created*: string
    sourceIp*: string
  PhiAccessLog* = object
    records*: seq[PhiAccessRecord]
    maxRecords*: int
  AlertSeverity* {.pure.} = enum Info, Warning, Critical, Emergency
  AlertKind* {.pure.} = enum AnomalousAccess, BulkExport, OffHoursAccess, FailedAuth
  Alert* = object
    id*: string
    alertType*: AlertKind
    severity*: AlertSeverity
    userId*: string
    message*: string
    created*: string
  AlertLog* = object
    alerts*: seq[Alert]

func defaultBreachConfig*(): BreachConfig =
  BreachConfig(anomalyThreshold: 3.0, cooldownSec: 3600, windowSec: 3600)

proc updateBaseline*(profile: var AccessProfile, count: int) =
  let n = float(profile.sampleCount)
  profile.hourlyBaseline = (profile.hourlyBaseline * n + float(count)) / (n + 1.0)
  profile.sampleCount += 1

func computeAnomaly*(profile: AccessProfile, currentRate: float): AnomalyScore =
  let diff = abs(currentRate - profile.hourlyBaseline)
  let score = if profile.hourlyBaseline > 0.0: diff / max(profile.hourlyBaseline, 1.0) else: 0.0
  AnomalyScore(userId: profile.userId, score: score, hourlyRate: currentRate)

func isAnomalous*(score: AnomalyScore, threshold: float = 3.0): bool =
  score.score > threshold

proc addRecord*(log: var PhiAccessLog, record: PhiAccessRecord) =
  log.records.add(record)
  if log.maxRecords > 0 and log.records.len > log.maxRecords:
    log.records.delete(0)

func isOffHours*(created: string, startHour: int = 7, endHour: int = 19): bool =
  # Simple check: extract hour from ISO created "...THH:..."
  let tPos = created.find('T')
  if tPos >= 0 and created.len > tPos + 2:
    let hour = parseInt(created[tPos+1 .. tPos+2])
    return hour < startHour or hour >= endHour
  false

func countByUser*(log: PhiAccessLog, userId: string): int =
  for r in log.records:
    if r.userId == userId: inc result

func getOffHoursAccess*(log: PhiAccessLog, startHour: int = 7, endHour: int = 19): seq[PhiAccessRecord] =
  for r in log.records:
    if isOffHours(r.created, startHour, endHour): result.add(r)

func detectBulkExport*(log: PhiAccessLog, userId: string, threshold: int = 100): bool =
  countByUser(log, userId) >= threshold

proc addAlert*(log: var AlertLog, alert: Alert) =
  log.alerts.add(alert)

func getActiveAlerts*(log: AlertLog, severity: AlertSeverity): seq[Alert] =
  for a in log.alerts:
    if a.severity == severity: result.add(a)
