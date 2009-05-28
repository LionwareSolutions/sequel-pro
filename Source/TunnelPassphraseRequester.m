//
//  TunnelPassphraseRequester.m
//  sequel-pro
//
//  Created by Rowan Beentje on May 4, 2009.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Cocoa/Cocoa.h>
#import "KeyChain.h"
#import "SPSSHTunnel.h"

int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *environment = [[NSProcessInfo processInfo] environment];

	if (![environment objectForKey:@"SP_PASSWORD_METHOD"]) {
		[pool release];
		return 1;
	}

	// If the password method is set to use the keychain, use the supplied keychain name to
	// request the password
	if ([[environment objectForKey:@"SP_PASSWORD_METHOD"] intValue] == SPSSH_PASSWORD_USES_KEYCHAIN) {
		KeyChain *keychain;
		NSString *keychainName = [environment objectForKey:@"SP_KEYCHAIN_ITEM_NAME"];
		NSString *keychainAccount = [environment objectForKey:@"SP_KEYCHAIN_ITEM_ACCOUNT"];

		if (!keychainName || !keychainAccount) {
			NSLog(@"SSH Tunnel: keychain authentication specified but insufficient internal details supplied");
			[pool release];
			return 1;
		}

		keychain = [[KeyChain alloc] init];
		if (![keychain passwordExistsForName:keychainName account:keychainAccount]) {
			NSLog(@"SSH Tunnel: specified keychain password not found");
			[pool release];
			return 1;
		}

		printf("%s\n", [[keychain getPasswordForName:keychainName account:keychainAccount] UTF8String]);
		[pool release];
		return 0;
	}

	// If the password method is set to request the password from the tunnel instance, do so.
	if ([[environment objectForKey:@"SP_PASSWORD_METHOD"] intValue] == SPSSH_PASSWORD_ASKS_UI) {
		SPSSHTunnel *sequelProTunnel;
		NSString *password;
		NSString *connectionName = [environment objectForKey:@"SP_CONNECTION_NAME"];
		NSString *verificationHash = [environment objectForKey:@"SP_CONNECTION_VERIFY_HASH"];
		
		if (!connectionName || !verificationHash) {
			NSLog(@"SSH Tunnel: internal authentication specified but insufficient details supplied");
			[pool release];
			return 1;
		}

		sequelProTunnel = (SPSSHTunnel *)[NSConnection rootProxyForConnectionWithRegisteredName:connectionName host:nil];
		if (!sequelProTunnel) {
			NSLog(@"SSH Tunnel: unable to connect to Sequel Pro for internal authentication");
			[pool release];
			return 1;
		}
		
		password = [sequelProTunnel getPasswordWithVerificationHash:verificationHash];
		if (!password) {
			NSLog(@"SSH Tunnel: unable to successfully request password from Sequel Pro for internal authentication");
			[pool release];
			return 1;
		}

		printf("%s\n", [password UTF8String]);
		[pool release];
		return 0;
	}

	[pool release];
	return 1;
}