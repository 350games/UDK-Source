using System;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Threading;

namespace AgentInterface
{
    [Serializable]
    public struct Constants
    {
        public static readonly int SUCCESS = 0;
        public static readonly int INVALID = -1;
        public static readonly int ERROR_FILE_FOUND_NOT = -2;
        public static readonly int ERROR_NULL_POINTER = -3;
        public static readonly int ERROR_EXCEPTION = -4;
        public static readonly int ERROR_INVALID_ARG = -5;
        public static readonly int ERROR_INVALID_ARG1 = -6;
        public static readonly int ERROR_INVALID_ARG2 = -7;
        public static readonly int ERROR_INVALID_ARG3 = -8;
        public static readonly int ERROR_INVALID_ARG4 = -9;
        public static readonly int ERROR_CHANNEL_NOT_FOUND = -10;
        public static readonly int ERROR_CHANNEL_NOT_READY = -11;
        public static readonly int ERROR_CHANNEL_IO_FAILED = -12;
        public static readonly int ERROR_CONNECTION_NOT_FOUND = -13;
        public static readonly int ERROR_JOB_NOT_FOUND = -14;
        public static readonly int ERROR_JOB = -15;
        public static readonly int ERROR_CONNECTION_DISCONNECTED = -16;
    }

    [Serializable]
    public enum ESwarmVersionValue
    {
        INVALID = 0x00000000,
        VER_1_0 = 0x00000010
    }

    [Serializable]
    public enum ELogFlags
    {
        LOG_NONE = 0,
        LOG_TIMINGS = 1 << 0,
        LOG_CONNECTIONS = 1 << 1,
        LOG_CHANNELS = 1 << 2,
        LOG_MESSAGES = 1 << 3,
        LOG_JOBS = 1 << 4,
        LOG_TASKS = 1 << 5,
        LOG_ALL = LOG_TIMINGS | LOG_CONNECTIONS | LOG_CHANNELS | LOG_MESSAGES | LOG_JOBS | LOG_TASKS
    }

    [Serializable]
    public enum EVerbosityLevel
    {
        Silent = 0,
        Critical,
        Simple,
        Informative,
        Complex,
        Verbose,
        ExtraVerbose,
        SuperVerbose
    }

    [Serializable]
    public enum EProgressionState
    {
        TaskTotal = 0,
        TasksInProgress = 1,
        TasksCompleted = 2,
        Idle = 3,
        InstigatorConnected = 4,
        RemoteConnected = 5,
        Exporting = 6,
        BeginJob = 7,
        Blocked = 8,
        Preparing0 = 9,
        Preparing1 = 10,
        Preparing2 = 11,
        Preparing3 = 12,
        Processing0 = 13,
        FinishedProcessing0 = 17,
        Processing1 = 14,
        FinishedProcessing1 = 18,
        Processing2 = 15,
        FinishedProcessing2 = 19,
        Processing3 = 16,
        FinishedProcessing3 = 20,
        ExportingResults = 21,
        ImportingResults = 22,
        Finished = 23,
        RemoteDisconnected = 24,
        InstigatorDisconnected = 25
    }

    [Serializable]
    public enum EChannelFlags
    {
        TYPE_PERSISTENT = 0x00000001,
        TYPE_JOB_ONLY = 0x00000002,
        TYPE_MASK = 0x0000000F,
        ACCESS_READ = 0x00000010,
        ACCESS_WRITE = 0x00000020,
        ACCESS_MASK = 0x000000F0,
        MISC_ENABLE_PAPER_TRAIL = 0x00010000,
        MISC_MASK = unchecked((int)0xFFFF0000)
    }

    [Serializable]
    public enum EMessageType
    {
        NONE = 0x00000000,
        INFO = 0x00000001,
        ALERT = 0x00000002,
        TIMING = 0x00000003,
        PING = 0x00000004,
        SIGNAL = 0x00000005,
        JOB_SPECIFICATION = 0x00000010,
        JOB_STATE = 0x00000020,
        TASK_REQUEST = 0x00000100,
        TASK_REQUEST_RESPONSE = 0x00000200,
        TASK_STATE = 0x00000300,
        QUIT = unchecked((int)0xDEADDEAD)
    }

    [Serializable]
    public enum ETaskRequestResponseType
    {
        RELEASE = 0x00000001,
        RESERVATION = 0x00000002,
        SPECIFICATION = 0x00000003
    }

    [Serializable]
    public enum EJobTaskFlags
    {
        FLAG_USE_DEFAULTS = 0x00000000,
        FLAG_ALLOW_REMOTE = 0x00000001,
        FLAG_MANUAL_START = 0x00000002,
        FLAG_64BIT = 0x00000004,
        TASK_FLAG_USE_DEFAULTS = 0x00000000,
        TASK_FLAG_ALLOW_REMOTE = 0x00000100
    }

    [Serializable]
    public enum EJobTaskState
    {
        STATE_INVALID = 0x00000001,
        STATE_IDLE = 0x00000002,
        STATE_READY = 0x00000003,
        STATE_RUNNING = 0x00000004,
        STATE_COMPLETE_SUCCESS = 0x00000005,
        STATE_COMPLETE_FAILURE = 0x00000006,
        STATE_KILLED = 0x00000007,
        TASK_STATE_INVALID = 0x00000011,
        TASK_STATE_IDLE = 0x00000012,
        TASK_STATE_ACCEPTED = 0x00000013,
        TASK_STATE_REJECTED = 0x00000014,
        TASK_STATE_RUNNING = 0x00000015,
        TASK_STATE_COMPLETE_SUCCESS = 0x00000016,
        TASK_STATE_COMPLETE_FAILURE = 0x00000017,
        TASK_STATE_KILLED = 0x00000018
    }

    [Serializable]
    public enum EAlertLevel
    {
        ALERT_INFO = 0x00000001,
        ALERT_WARNING = 0x00000002,
        ALERT_ERROR = 0x00000003,
        ALERT_CRITICAL_ERROR = 0x00000004
    }

    [Serializable]
    public class AgentGuid : IEquatable<AgentGuid>
    {
        public uint A;
        public uint B;
        public uint C;
        public uint D;

        public AgentGuid()
        {
        }

        public AgentGuid(uint inA, uint inB, uint inC, uint inD)
        {
            A = inA;
            B = inB;
            C = inC;
            D = inD;
        }

        public bool Equals(AgentGuid other)
        {
            return other != null && A == other.A && B == other.B && C == other.C && D == other.D;
        }

        public override int GetHashCode()
        {
            return (int)(A ^ B ^ C ^ D);
        }

        public override string ToString()
        {
            return string.Format("{0:X8}-{1:X8}-{2:X8}-{3:X8}", A, B, C, D);
        }
    }

    [Serializable]
    public class AgentMessage
    {
        public int To;
        public int From;
        public ESwarmVersionValue Version;
        public EMessageType Type;

        public AgentMessage()
            : this(ESwarmVersionValue.VER_1_0, EMessageType.NONE)
        {
        }

        public AgentMessage(EMessageType newType)
            : this(ESwarmVersionValue.VER_1_0, newType)
        {
        }

        public AgentMessage(ESwarmVersionValue newVersion, EMessageType newType)
        {
            To = Constants.INVALID;
            From = Constants.INVALID;
            Version = newVersion;
            Type = newType;
        }
    }

    [Serializable]
    public class AgentInfoMessage : AgentMessage
    {
        public string TextMessage;

        public AgentInfoMessage()
            : base(EMessageType.INFO)
        {
        }

        public AgentInfoMessage(string newTextMessage)
            : base(EMessageType.INFO)
        {
            TextMessage = newTextMessage;
        }
    }

    [Serializable]
    public class AgentTimingMessage : AgentMessage
    {
        public EProgressionState State;
        public int ThreadNum;

        public AgentTimingMessage(EProgressionState newState, int inThreadNum)
            : base(EMessageType.TIMING)
        {
            State = newState;
            ThreadNum = inThreadNum;
        }
    }

    [Serializable]
    public class AgentJobMessageBase : AgentMessage
    {
        public AgentGuid JobGuid;

        public AgentJobMessageBase(AgentGuid newJobGuid, EMessageType newType)
            : base(newType)
        {
            JobGuid = newJobGuid;
        }
    }

    [Serializable]
    public class AgentAlertMessage : AgentJobMessageBase
    {
        public EAlertLevel AlertLevel;
        public AgentGuid ObjectGuid;
        public int TypeId;
        public string TextMessage;

        public AgentAlertMessage(AgentGuid newJobGuid)
            : base(newJobGuid, EMessageType.ALERT)
        {
        }

        public AgentAlertMessage(AgentGuid newJobGuid, EAlertLevel newAlertLevel, AgentGuid newObjectGuid, int newTypeId, string newTextMessage)
            : base(newJobGuid, EMessageType.ALERT)
        {
            AlertLevel = newAlertLevel;
            ObjectGuid = newObjectGuid;
            TypeId = newTypeId;
            TextMessage = newTextMessage;
        }
    }

    [Serializable]
    public class AgentJobSpecification
    {
        public AgentGuid JobGuid;
        public EJobTaskFlags JobFlags;
        public string ExecutableName;
        public string Parameters;
        public List<string> RequiredDependencies;
        public List<string> OptionalDependencies;
        public Dictionary<string, string> DependenciesOriginalNames;

        public AgentJobSpecification(AgentGuid newJobGuid, EJobTaskFlags newJobFlags, string jobExecutableName, string jobParameters, List<string> jobRequiredDependencies, List<string> jobOptionalDependencies)
        {
            JobGuid = newJobGuid;
            JobFlags = newJobFlags;
            ExecutableName = jobExecutableName;
            Parameters = jobParameters;
            RequiredDependencies = jobRequiredDependencies;
            OptionalDependencies = jobOptionalDependencies;
            DependenciesOriginalNames = null;
        }
    }

    [Serializable]
    public class AgentSignalMessage : AgentMessage
    {
        public ManualResetEvent ResetEvent;

        public AgentSignalMessage()
            : base(EMessageType.SIGNAL)
        {
            ResetEvent = new ManualResetEvent(false);
        }
    }

    [Serializable]
    public class AgentTaskRequestResponse : AgentJobMessageBase
    {
        public ETaskRequestResponseType ResponseType;

        public AgentTaskRequestResponse(AgentGuid taskJobGuid, ETaskRequestResponseType taskResponseType)
            : base(taskJobGuid, EMessageType.TASK_REQUEST_RESPONSE)
        {
            ResponseType = taskResponseType;
        }
    }

    [Serializable]
    public class AgentTaskSpecification : AgentTaskRequestResponse
    {
        public AgentGuid TaskGuid;
        public int TaskFlags;
        public string Parameters;
        public int Cost;
        public List<string> Dependencies;
        public Dictionary<string, string> DependenciesOriginalNames;

        public AgentTaskSpecification(AgentGuid taskJobGuid, AgentGuid taskTaskGuid, int taskTaskFlags, string taskParameters, int taskCost, List<string> taskDependencies)
            : base(taskJobGuid, ETaskRequestResponseType.SPECIFICATION)
        {
            TaskGuid = taskTaskGuid;
            TaskFlags = taskTaskFlags;
            Parameters = taskParameters;
            Cost = taskCost;
            Dependencies = taskDependencies;
            DependenciesOriginalNames = null;
        }
    }

    [Serializable]
    public class AgentJobState : AgentJobMessageBase
    {
        public EJobTaskState JobState;
        public string JobMessage;
        public double JobRunningTime;
        public int JobExitCode;

        public AgentJobState(AgentGuid newJobGuid, EJobTaskState newJobState)
            : base(newJobGuid, EMessageType.JOB_STATE)
        {
            JobState = newJobState;
        }
    }

    [Serializable]
    public class AgentTaskState : AgentJobMessageBase
    {
        public AgentGuid TaskGuid;
        public EJobTaskState TaskState;
        public string TaskMessage;
        public double TaskRunningTime;
        public int TaskExitCode;

        public AgentTaskState(AgentGuid newJobGuid, AgentGuid newTaskGuid, EJobTaskState newTaskState)
            : base(newJobGuid, EMessageType.TASK_STATE)
        {
            TaskGuid = newTaskGuid;
            TaskState = newTaskState;
        }
    }

    public interface IAgentInterface
    {
        int OpenConnection(Hashtable inParameters, ref Hashtable outParameters);
        int CloseConnection(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int SendMessage(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int GetMessage(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int AddChannel(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int TestChannel(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int OpenChannel(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int CloseChannel(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int OpenJob(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int BeginJobSpecification(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int AddTask(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int EndJobSpecification(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int CloseJob(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int Method(int connectionHandle, Hashtable inParameters, ref Hashtable outParameters);
        int Log(EVerbosityLevel verbosity, Color textColour, string line);
    }
}
