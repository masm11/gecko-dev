/* -*- Mode: C++; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include <X11/X.h>
#include <X11/Xlib.h>

#include "nsRemoteClient.h"
#if defined(MOZ_WAYLAND) && defined(MOZ_ENABLE_DBUS)
#define  ENABLE_REMOTE_DBUS 1
#include "mozilla/ipc/DBusConnectionRefPtr.h"
#endif

class XRemoteClient : public nsRemoteClient
{
public:
  XRemoteClient();
  ~XRemoteClient();

  virtual nsresult Init();
  virtual nsresult SendCommandLine(const char *aProgram, const char *aUsername,
                                   const char *aProfile,
                                   int32_t argc, char **argv,
                                   const char* aDesktopStartupID,
                                   char **aResponse, bool *aSucceeded);
  void Shutdown();

private:

  Window         CheckWindow      (Window aWindow);
  Window         CheckChildren    (Window aWindow);
  nsresult       GetLock          (Window aWindow, bool *aDestroyed);
  nsresult       FreeLock         (Window aWindow);
  Window         FindBestWindow   (const char *aProgram,
                                   const char *aUsername,
                                   const char *aProfile);
  nsresult       DoSendCommandLine(Window aWindow,
                                   int32_t argc, char **argv,
                                   const char* aDesktopStartupID,
                                   char **aResponse,
                                   bool *aDestroyed,
                                   const char *aProgram,
                                   const char *aProfile);
  bool           WaitForResponse  (Window aWindow, char **aResponse,
                                   bool *aDestroyed, Atom aCommandAtom);
#ifdef ENABLE_REMOTE_DBUS
  nsresult       DoSendDBusCommandLine(const char *aProgram, const char *aProfile,
                                       unsigned char* aBuffer, int aLength);
#endif

  Display       *mDisplay;

  Atom           mMozVersionAtom;
  Atom           mMozLockAtom;
  Atom           mMozCommandLineAtom;
  Atom           mMozResponseAtom;
  Atom           mMozWMStateAtom;
  Atom           mMozUserAtom;
  Atom           mMozProfileAtom;
  Atom           mMozProgramAtom;

  char          *mLockData;

  bool           mInitialized;
#ifdef ENABLE_REMOTE_DBUS
  bool           mIsX11Display;
  RefPtr<DBusConnection> mConnection;
#endif
};
