resource "aws_dms_replication_task" "event_prod_migration_task" {
  replication_task_id      = "event-prod-migration-task"
  replication_instance_arn = "arn:aws:dms:ap-northeast-2:605134473022:rep:EGQT5GSZCZE4NCSHAAAHJXFLGI"
  source_endpoint_arn      = "arn:aws:dms:ap-northeast-2:605134473022:endpoint:YXRYJTPZAJHFBDRKFZHBDPEZ3A"
  target_endpoint_arn      = "arn:aws:dms:ap-northeast-2:605134473022:endpoint:PBLCPN6RD5CEROWPPRL46NX37M"
  migration_type           = "full-load"

  replication_task_settings = jsonencode({
    BeforeImageSettings = null
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableAltered   = true
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
    }
    ChangeProcessingTuning = {
      BatchApplyMemoryLimit         = 500
      BatchApplyPreserveTransaction = true
      BatchApplyTimeoutMax          = 30
      BatchApplyTimeoutMin          = 1
      BatchSplitSize                = 0
      CommitTimeout                 = 1
      MemoryKeepTime                = 60
      MemoryLimitTotal              = 1024
      MinTransactionSize            = 1000
      RecoveryTimeout               = -1
      StatementCacheSize            = 50
    }
    CharacterSetSettings = null
    ControlTablesSettings = {
      ControlSchema                 = ""
      FullLoadExceptionTableEnabled = false
      HistoryTableEnabled           = false
      HistoryTimeslotInMinutes      = 5
      StatusTableEnabled            = true
      SuspendedTablesTableEnabled   = false
      historyTimeslotInMinutes      = 5
    }
    ErrorBehavior = {
      ApplyErrorDeletePolicy                      = "LOG_ERROR"
      ApplyErrorEscalationCount                   = 0
      ApplyErrorEscalationPolicy                  = "LOG_ERROR"
      ApplyErrorFailOnTruncationDdl               = false
      ApplyErrorInsertPolicy                      = "LOG_ERROR"
      ApplyErrorUpdatePolicy                      = "LOG_ERROR"
      DataErrorEscalationCount                    = 0
      DataErrorEscalationPolicy                   = "SUSPEND_TABLE"
      DataErrorPolicy                             = "LOG_ERROR"
      DataMaskingErrorPolicy                      = "STOP_TASK"
      DataTruncationErrorPolicy                   = "LOG_ERROR"
      EventErrorPolicy                            = "IGNORE"
      FailOnNoTablesCaptured                      = true
      FailOnTransactionConsistencyBreached        = false
      FullLoadIgnoreConflicts                     = false
      RecoverableErrorCount                       = -1
      RecoverableErrorInterval                    = 5
      RecoverableErrorStopRetryAfterThrottlingMax = true
      RecoverableErrorThrottling                  = true
      RecoverableErrorThrottlingMax               = 1800
      TableErrorEscalationCount                   = 0
      TableErrorEscalationPolicy                  = "STOP_TASK"
      TableErrorPolicy                            = "STOP_TASK"
    }
    FailTaskWhenCleanTaskResourceFailed = false
    FullLoadSettings = {
      CommitRate                      = 10000
      CreatePkAfterFullLoad           = true
      MaxFullLoadSubTasks             = 8
      StopTaskCachedChangesApplied    = false
      StopTaskCachedChangesNotApplied = false
      TargetTablePrepMode             = "DROP_AND_CREATE"
      TransactionConsistencyTimeout   = 600
    }
    
    LoopbackPreventionSettings = null
    PostProcessingRules = null
    StreamBufferSettings = {
      CtrlStreamBufferSizeInMB = 5
      StreamBufferCount        = 3
      StreamBufferSizeInMB     = 8
    }
    TTSettings = null
    TargetMetadata = {
      BatchApplyEnabled            = true
      FullLobMode                  = false
      InlineLobMaxSize             = 0
      LimitedSizeLobMode           = false
      LoadMaxFileSize              = 0
      LobChunkSize                 = 0
      LobMaxSize                   = 0
      ParallelApplyBufferSize      = 0
      ParallelApplyQueuesPerThread = 0
      ParallelApplyThreads         = 0
      ParallelLoadBufferSize       = 0
      ParallelLoadQueuesPerThread  = 0
      ParallelLoadThreads          = 0
      SupportLobs                  = false
      TargetSchema                 = "eventdb"
      TaskRecoveryTableEnabled     = false
    }
    ValidationSettings = {
      EnableValidation                 = true
      FailureMaxCount                  = 1000
      HandleCollationDiff              = false
      MaxKeyColumnSize                 = 8096
      PartitionSize                    = 1000
      RecordFailureDelayInMinutes      = 5
      RecordFailureDelayLimitInMinutes = 0
      RecordSuspendDelayInMinutes      = 30
      SkipLobColumns                   = false
      TableFailureMaxCount             = 1000
      ThreadCount                      = 5
      ValidationMode                   = "ROW_LEVEL"
      ValidationOnly                   = false
      ValidationPartialLobSize         = 0
      ValidationQueryCdcDelaySeconds   = 0
      ValidationS3Mask                 = 0
      ValidationS3Time                 = 0
    }
  })
  
  table_mappings            = jsonencode({
    rules = [
      {
        object-locator = {
          schema-name = "eventdb"
          table-name  = "%"
        }
        rule-action = "include"
        rule-id     = "1"
        rule-name   = "IncludeEventSchema"
        rule-type   = "selection"
      }
    ]
  })
  
  tags = {}
  tags_all = {}

   depends_on = [
    aws_dms_endpoint.source_endpoint,
    aws_dms_endpoint.target_endpoint,
    aws_dms_replication_instance.dms_event_to_prod 
   ]
}

