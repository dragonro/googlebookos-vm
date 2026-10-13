package com.googlebook.vm.keyboardlayouts;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Advertises the built-in French (Mac) key character map in Physical keyboard settings. */
public final class KeyboardLayoutProvider extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        // Android discovers the layout from the receiver's manifest metadata.
    }
}
