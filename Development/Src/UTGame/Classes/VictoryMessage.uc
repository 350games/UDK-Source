class VictoryMessage extends UTLocalMessage;

var SoundNodeWave VictorySounds[6];

static function byte AnnouncementLevel(byte MessageIndex)
{
	return 1;
}

static function SoundNodeWave AnnouncementSound(int MessageIndex, Object OptionalObject, PlayerController PC)
{
	if (MessageIndex < 0 || MessageIndex >= ArrayCount(Default.VictorySounds))
	{
		return None;
	}

	return Default.VictorySounds[MessageIndex];
}

/** Victory announcements supersede all ordinary queued announcements. */
static function bool AddAnnouncement(
	UTAnnouncer Announcer,
	int MessageIndex,
	optional PlayerReplicationInfo PRI,
	optional Object OptionalObject)
{
	local UTQueuedAnnouncement RemovedAnnouncement;

	while (Announcer.Queue != None)
	{
		RemovedAnnouncement = Announcer.Queue;
		Announcer.Queue = Announcer.Queue.NextAnnouncement;
		RemovedAnnouncement.Destroy();
	}

	Super.AddAnnouncement(Announcer, MessageIndex, PRI, OptionalObject);
	return Announcer.PlayingAnnouncementClass == None ||
		Announcer.PlayingAnnouncementClass.Static.KilledByVictoryMessage(Announcer.PlayingAnnouncementIndex);
}

defaultproperties
{
	bIsConsoleMessage=true
	VictorySounds(0)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_FlawlessVictory'
	VictorySounds(1)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_HumiliatingDefeat'
	VictorySounds(2)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_YouHaveWonTheMatch'
	VictorySounds(3)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_YouHaveLostTheMatch'
	VictorySounds(4)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_RedTeamWinsTheMatch'
	VictorySounds(5)=SoundNodeWave'A_Announcer_Status.Status.A_StatusAnnouncer_BlueTeamWinsTheMatch'
}
