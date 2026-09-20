class UTAnnouncer extends Info
	config(Game);

/** 0 disables announcements, 1 plays important announcements, and 2 plays all announcements. */
var globalconfig byte AnnouncerLevel;

/** The announcement currently being played. */
var class<UTLocalMessage> PlayingAnnouncementClass;
var int PlayingAnnouncementIndex;

/** Announcements waiting to be played. */
var UTQueuedAnnouncement Queue;

var UTPlayerController PlayerOwner;

/**
 * Shared cue containing the SoundNodeWave parameter named Announcement. Message classes
 * provide the wave while this cue supplies common announcer routing and playback setup.
 */
var SoundCue AnnouncerSoundCue;

/** Audio component currently playing the shared cue. */
var AudioComponent CurrentAnnouncementComponent;

function Destroyed()
{
	local UTQueuedAnnouncement Announcement;

	ClearTimer('AnnouncementFinished');
	ReleaseCurrentAnnouncement(true);

	while (Queue != None)
	{
		Announcement = Queue;
		Queue = Queue.NextAnnouncement;
		Announcement.Destroy();
	}

	Super.Destroyed();
}

function PostBeginPlay()
{
	Super.PostBeginPlay();
	PlayerOwner = UTPlayerController(Owner);
}

/** Stops and detaches the active component without advancing the queue. */
function ReleaseCurrentAnnouncement(optional bool bStopSound)
{
	local AudioComponent AnnouncementComponent;

	AnnouncementComponent = CurrentAnnouncementComponent;
	CurrentAnnouncementComponent = None;

	if (AnnouncementComponent != None)
	{
		AnnouncementComponent.OnAudioFinished = None;
		if (bStopSound && !AnnouncementComponent.bFinished)
		{
			AnnouncementComponent.Stop();
		}
		if (PlayerOwner != None)
		{
			PlayerOwner.DetachComponent(AnnouncementComponent);
		}
	}
}

function PlayNextAnnouncement()
{
	local UTQueuedAnnouncement NextAnnouncement;

	PlayingAnnouncementClass = None;

	if (Queue != None)
	{
		NextAnnouncement = Queue;
		Queue = NextAnnouncement.NextAnnouncement;
		PlayAnnouncementNow(
			NextAnnouncement.AnnouncementClass,
			NextAnnouncement.MessageIndex,
			NextAnnouncement.PRI,
			NextAnnouncement.OptionalObject);
		NextAnnouncement.Destroy();
	}
}

function PlayAnnouncementNow(
	class<UTLocalMessage> InMessageClass,
	int MessageIndex,
	optional PlayerReplicationInfo PRI,
	optional Object OptionalObject)
{
	local SoundNodeWave AnnouncementWave;
	local float AnnouncementDuration;

	if (InMessageClass == None || PlayerOwner == None)
	{
		PlayNextAnnouncement();
		return;
	}

	AnnouncementWave = InMessageClass.Static.AnnouncementSound(MessageIndex, OptionalObject, PlayerOwner);
	if (AnnouncementWave == None)
	{
		PlayNextAnnouncement();
		return;
	}

	ClearTimer('AnnouncementFinished');
	ReleaseCurrentAnnouncement(true);

	CurrentAnnouncementComponent = PlayerOwner.CreateAudioComponent(AnnouncerSoundCue, false, false);
	if (CurrentAnnouncementComponent != None)
	{
		CurrentAnnouncementComponent.SetWaveParameter('Announcement', AnnouncementWave);
		AnnouncerSoundCue.Duration = AnnouncementWave.Duration;
		AnnouncerSoundCue.VolumeMultiplier = InMessageClass.Default.AnnouncementVolume;
		CurrentAnnouncementComponent.bAutoDestroy = true;
		CurrentAnnouncementComponent.bShouldRemainActiveIfDropped = true;
		CurrentAnnouncementComponent.bAllowSpatialization = false;
		CurrentAnnouncementComponent.bAlwaysPlay = true;
		CurrentAnnouncementComponent.OnAudioFinished = AnnouncementFinished;
		CurrentAnnouncementComponent.Play();
	}

	PlayingAnnouncementClass = InMessageClass;
	PlayingAnnouncementIndex = MessageIndex;

	// Audio plays in real time, while Actor timers are affected by time dilation.
	AnnouncementDuration = AnnouncementWave.Duration * WorldInfo.TimeDilation + 0.05;
	if (AnnouncementDuration < 0.05)
	{
		AnnouncementDuration = 0.05;
	}
	SetTimer(AnnouncementDuration, false, 'AnnouncementFinished');
}

/** Called by the AudioComponent delegate, with the timer serving as a no-audio/failsafe path. */
function AnnouncementFinished(optional AudioComponent FinishedComponent)
{
	if (FinishedComponent != None && FinishedComponent != CurrentAnnouncementComponent)
	{
		return;
	}

	ClearTimer('AnnouncementFinished');
	ReleaseCurrentAnnouncement(false);
	PlayingAnnouncementClass = None;
	PlayNextAnnouncement();
}

function PlayAnnouncement(
	class<UTLocalMessage> InMessageClass,
	int MessageIndex,
	optional PlayerReplicationInfo PRI,
	optional Object OptionalObject)
{
	if (InMessageClass == None || InMessageClass.Static.AnnouncementLevel(MessageIndex) > AnnouncerLevel)
	{
		return;
	}

	if (CurrentAnnouncementComponent != None && CurrentAnnouncementComponent.bFinished)
	{
		ClearTimer('AnnouncementFinished');
		ReleaseCurrentAnnouncement(false);
		PlayingAnnouncementClass = None;
	}

	if (PlayingAnnouncementClass == None)
	{
		if (InMessageClass.Default.AnnouncementDelay == 0.0 || (PRI != None && !PRI.bBot))
		{
			PlayAnnouncementNow(InMessageClass, MessageIndex, PRI, OptionalObject);
			return;
		}

		SetTimer(
			InMessageClass.Default.AnnouncementDelay * WorldInfo.TimeDilation,
			false,
			'AnnouncementFinished');
	}

	if (InMessageClass.Static.AddAnnouncement(self, MessageIndex, PRI, OptionalObject))
	{
		ClearTimer('AnnouncementFinished');
		ReleaseCurrentAnnouncement(true);
		PlayingAnnouncementClass = None;
		PlayNextAnnouncement();
	}
}

defaultproperties
{
	AnnouncerSoundCue=SoundCue'A_Announcer_Reward_Cue.SoundCues.AnnouncerCue'
}
