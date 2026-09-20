class UTLocalMessage extends LocalMessage
	abstract;

/** Used for ordering messages in the announcement queue. */
var int AnnouncementPriority;

/** Per-message volume multiplier for announcer audio. */
var float AnnouncementVolume;

/** Optional delay before an announcement is allowed to play. */
var float AnnouncementDelay;

static function byte AnnouncementLevel(byte MessageIndex)
{
	return 1;
}

/** Return the wave inserted into UTAnnouncer's shared SoundCue. */
static function SoundNodeWave AnnouncementSound(int MessageIndex, Object OptionalObject, PlayerController PC);

/** Allow queued messages to remove themselves when made obsolete by a newer message. */
static function bool ShouldBeRemoved(
	UTQueuedAnnouncement MyAnnouncement,
	class<UTLocalMessage> NewAnnouncementClass,
	int NewMessageIndex)
{
	return false;
}

/** Insert a new announcement according to message priority. */
static function bool AddAnnouncement(
	UTAnnouncer Announcer,
	int MessageIndex,
	optional PlayerReplicationInfo PRI,
	optional Object OptionalObject)
{
	local UTQueuedAnnouncement NewAnnouncement, Announcement, RemovedAnnouncement;
	local bool bPlacedAnnouncement;

	if (Announcer == None)
	{
		return false;
	}

	NewAnnouncement = Announcer.Spawn(class'UTQueuedAnnouncement');
	if (NewAnnouncement == None)
	{
		return false;
	}

	NewAnnouncement.AnnouncementClass = Default.Class;
	NewAnnouncement.MessageIndex = MessageIndex;
	NewAnnouncement.PRI = PRI;
	NewAnnouncement.OptionalObject = OptionalObject;

	if (Announcer.Queue != None &&
		Announcer.Queue.AnnouncementClass.Static.ShouldBeRemoved(Announcer.Queue, Default.Class, MessageIndex))
	{
		RemovedAnnouncement = Announcer.Queue;
		Announcer.Queue = Announcer.Queue.NextAnnouncement;
		RemovedAnnouncement.Destroy();
	}

	if (Announcer.Queue == None)
	{
		Announcer.Queue = NewAnnouncement;
	}
	else
	{
		if (Default.AnnouncementPriority > Announcer.Queue.AnnouncementClass.Default.AnnouncementPriority)
		{
			NewAnnouncement.NextAnnouncement = Announcer.Queue;
			Announcer.Queue = NewAnnouncement;
			bPlacedAnnouncement = true;
		}

		for (Announcement = Announcer.Queue; Announcement != None; Announcement = Announcement.NextAnnouncement)
		{
			if (Announcement.NextAnnouncement == None)
			{
				if (!bPlacedAnnouncement)
				{
					Announcement.NextAnnouncement = NewAnnouncement;
				}
				break;
			}

			if (!bPlacedAnnouncement &&
				Default.AnnouncementPriority > Announcement.NextAnnouncement.AnnouncementClass.Default.AnnouncementPriority)
			{
				bPlacedAnnouncement = true;
				NewAnnouncement.NextAnnouncement = Announcement.NextAnnouncement;
				Announcement.NextAnnouncement = NewAnnouncement;
			}
			else if (Announcement.NextAnnouncement.AnnouncementClass.Static.ShouldBeRemoved(
				Announcement.NextAnnouncement, Default.Class, MessageIndex))
			{
				RemovedAnnouncement = Announcement.NextAnnouncement;
				Announcement.NextAnnouncement = RemovedAnnouncement.NextAnnouncement;
				RemovedAnnouncement.Destroy();

				if (Announcement.NextAnnouncement == None)
				{
					if (!bPlacedAnnouncement)
					{
						Announcement.NextAnnouncement = NewAnnouncement;
					}
					break;
				}
			}
		}
	}

	return false;
}

static function bool KilledByVictoryMessage(int AnnouncementIndex)
{
	return Default.AnnouncementPriority < 6;
}

defaultproperties
{
	AnnouncementVolume=2.0
}
