/* -*- Mode: C++; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* vim: set ts=8 sts=2 et sw=2 tw=80: */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

 #ifndef GFX_VR_THREAD_H
 #define GFX_VR_THREAD_H

#include "ThreadSafeRefcountingWithMainThreadDestruction.h"
#include "base/thread.h"                // for Thread

namespace mozilla {
namespace gfx {

class VRListenerThreadHolder final
{
  NS_INLINE_DECL_THREADSAFE_REFCOUNTING_WITH_MAIN_THREAD_DESTRUCTION(VRListenerThreadHolder)

public:
  VRListenerThreadHolder();

  base::Thread* GetThread() const {
    return mThread;
  }

  static VRListenerThreadHolder* GetSingleton();

  static bool IsActive() {
    return !!GetSingleton();
  }

  static void Start();
  static void Shutdown();
  static MessageLoop* Loop();
  static bool IsInVRListenerThread();

private:
  ~VRListenerThreadHolder();

  base::Thread* const mThread;

  static base::Thread* CreateThread();
  static void DestroyThread(base::Thread* aThread);
};

base::Thread* VRListenerThread();

} // namespace gfx
} // namespace mozilla

#endif // GFX_VR_THREAD_H