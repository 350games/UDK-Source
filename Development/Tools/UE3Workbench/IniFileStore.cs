using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace UE3Workbench
{
	/// <summary>
	/// Small section-aware INI editor for Workbench-owned settings. It updates only
	/// the requested keys and leaves every other section, key, and comment intact.
	/// </summary>
	internal sealed class IniFileStore
	{
		private readonly string filePath;

		public IniFileStore( string filePath )
		{
			if( String.IsNullOrWhiteSpace( filePath ) )
			{
				throw new ArgumentException( "An INI file path is required.", "filePath" );
			}
			this.filePath = filePath;
		}

		public string GetValue( string sectionName, string keyName, string fallbackValue )
		{
			if( !File.Exists( filePath ) )
			{
				return fallbackValue;
			}

			bool inRequestedSection = false;
			string foundValue = null;
			foreach( string rawLine in File.ReadAllLines( filePath ) )
			{
				string section;
				if( TryGetSectionName( rawLine, out section ) )
				{
					if( inRequestedSection )
					{
						break;
					}
					inRequestedSection = String.Equals( section, sectionName, StringComparison.OrdinalIgnoreCase );
					continue;
				}

				if( !inRequestedSection )
				{
					continue;
				}

				string key;
				string value;
				if( TryGetKeyValue( rawLine, out key, out value ) &&
					String.Equals( key, keyName, StringComparison.OrdinalIgnoreCase ) )
				{
					foundValue = value;
				}
			}

			return foundValue ?? fallbackValue;
		}

		public void SetValues( string sectionName, IEnumerable<KeyValuePair<string, string>> values )
		{
			if( String.IsNullOrWhiteSpace( sectionName ) )
			{
				throw new ArgumentException( "An INI section name is required.", "sectionName" );
			}

			Dictionary<string, string> requestedValues = new Dictionary<string, string>( StringComparer.OrdinalIgnoreCase );
			List<string> requestedKeyOrder = new List<string>();
			foreach( KeyValuePair<string, string> entry in values )
			{
				if( String.IsNullOrWhiteSpace( entry.Key ) || entry.Key.IndexOf( '=' ) >= 0 )
				{
					throw new ArgumentException( "INI setting keys must be non-empty and cannot contain '='.", "values" );
				}
				string value = entry.Value ?? String.Empty;
				if( value.IndexOfAny( new[] { '\r', '\n' } ) >= 0 )
				{
					throw new ArgumentException( "INI setting values cannot contain new lines.", "values" );
				}
				if( !requestedValues.ContainsKey( entry.Key ) )
				{
					requestedKeyOrder.Add( entry.Key );
				}
				requestedValues[ entry.Key ] = value;
			}

			List<string> output = File.Exists( filePath )
				? new List<string>( File.ReadAllLines( filePath ) )
				: new List<string>();
			List<string> merged = new List<string>();
			HashSet<string> writtenKeys = new HashSet<string>( StringComparer.OrdinalIgnoreCase );
			bool foundSection = false;
			bool inRequestedSection = false;

			foreach( string rawLine in output )
			{
				string section;
				if( TryGetSectionName( rawLine, out section ) )
				{
					if( inRequestedSection )
					{
						AppendMissingValues( merged, requestedValues, requestedKeyOrder, writtenKeys );
					}

					inRequestedSection = String.Equals( section, sectionName, StringComparison.OrdinalIgnoreCase );
					if( inRequestedSection )
					{
						foundSection = true;
					}
					merged.Add( rawLine );
					continue;
				}

				if( inRequestedSection )
				{
					string key;
					string ignoredValue;
					if( TryGetKeyValue( rawLine, out key, out ignoredValue ) && requestedValues.ContainsKey( key ) )
					{
						if( writtenKeys.Add( key ) )
						{
							merged.Add( key + "=" + requestedValues[ key ] );
						}
						continue;
					}
				}

				merged.Add( rawLine );
			}

			if( foundSection )
			{
				if( inRequestedSection )
				{
					AppendMissingValues( merged, requestedValues, requestedKeyOrder, writtenKeys );
				}
			}
			else
			{
				if( merged.Count > 0 && !String.IsNullOrWhiteSpace( merged[ merged.Count - 1 ] ) )
				{
					merged.Add( String.Empty );
				}
				merged.Add( "[" + sectionName + "]" );
				AppendMissingValues( merged, requestedValues, requestedKeyOrder, writtenKeys );
			}

			WriteAllLinesAtomically( merged );
		}

		private static void AppendMissingValues(
			List<string> output,
			Dictionary<string, string> values,
			List<string> keyOrder,
			HashSet<string> writtenKeys )
		{
			foreach( string key in keyOrder )
			{
				if( writtenKeys.Add( key ) )
				{
					output.Add( key + "=" + values[ key ] );
				}
			}
		}

		private void WriteAllLinesAtomically( List<string> lines )
		{
			string directory = Path.GetDirectoryName( filePath );
			if( !String.IsNullOrWhiteSpace( directory ) )
			{
				Directory.CreateDirectory( directory );
			}

			string temporaryPath = filePath + ".incoming-" + Guid.NewGuid().ToString( "N" );
			try
			{
				File.WriteAllLines( temporaryPath, lines.ToArray(), new UTF8Encoding( false ) );
				File.Copy( temporaryPath, filePath, true );
			}
			finally
			{
				if( File.Exists( temporaryPath ) )
				{
					File.Delete( temporaryPath );
				}
			}
		}

		private static bool TryGetSectionName( string rawLine, out string sectionName )
		{
			string line = rawLine.Trim();
			if( line.Length >= 3 && line.StartsWith( "[", StringComparison.Ordinal ) && line.EndsWith( "]", StringComparison.Ordinal ) )
			{
				sectionName = line.Substring( 1, line.Length - 2 ).Trim();
				return sectionName.Length > 0;
			}
			sectionName = null;
			return false;
		}

		private static bool TryGetKeyValue( string rawLine, out string key, out string value )
		{
			string line = rawLine.Trim();
			if( line.Length == 0 || line.StartsWith( ";", StringComparison.Ordinal ) || line.StartsWith( "#", StringComparison.Ordinal ) )
			{
				key = null;
				value = null;
				return false;
			}

			int equalsIndex = line.IndexOf( '=' );
			if( equalsIndex <= 0 )
			{
				key = null;
				value = null;
				return false;
			}

			key = line.Substring( 0, equalsIndex ).Trim();
			value = line.Substring( equalsIndex + 1 ).Trim();
			return key.Length > 0;
		}
	}
}
