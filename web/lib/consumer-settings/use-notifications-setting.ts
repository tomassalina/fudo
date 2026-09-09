"use client";

import { useCallback, useEffect, useState } from "react";
import {
  createConsumerSetting,
  fetchConsumerSetting,
  updateConsumerSetting,
  type RawConsumerSetting,
} from "@/lib/api/consumer-settings";
import { ApiError } from "@/lib/api/client";
import { forceLogout } from "@/lib/session/session-provider";

export interface UseNotificationsSetting {
  /** Defaults to `true` (matches the previous UI-only mock's default)
   * until the real value loads, and again if this consumer has no
   * `ConsumerSetting` row yet (see lib/api/consumer-settings.ts). */
  notificationsEnabled: boolean;
  toggleNotifications: () => void;
}

/**
 * Backs SettingsTab's "Notificaciones" toggle with the real
 * `ConsumerSetting.notifications_enabled` column — this used to be
 * `useState(true)`, local-only, because reaching the backend needed a real
 * bearer token that didn't exist yet (see SettingsTab.tsx's now-outdated
 * header comment). "Alertas de precio" stays local-only on purpose: that
 * field doesn't exist on `ConsumerSetting` at all (confirmed against
 * `backend/app/models/consumer_setting.rb` — only `theme` and
 * `notifications_enabled`), so there's nothing real to persist it to yet.
 *
 * Not optimistic-with-rollback for the toggle itself: the request is small
 * and local to this one row, so it just shows the previous value again if
 * the request fails rather than juggling a rollback of an in-flight
 * optimistic update.
 */
export function useNotificationsSetting(): UseNotificationsSetting {
  const [setting, setSetting] = useState<RawConsumerSetting | null>(null);
  const [override, setOverride] = useState<boolean | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchConsumerSetting()
      .then((result) => {
        if (!cancelled) setSetting(result);
      })
      .catch((error) => {
        if (error instanceof ApiError && error.status === 401) forceLogout();
        // Any other failure: keep the `true` default rather than blocking
        // the rest of Ajustes on one setting's load.
      });
    return () => {
      cancelled = true;
    };
  }, []);

  const notificationsEnabled = override ?? setting?.notifications_enabled ?? true;

  const toggleNotifications = useCallback(() => {
    const next = !notificationsEnabled;
    setOverride(next);

    const persist = setting
      ? updateConsumerSetting(setting.id, { notifications_enabled: next })
      : createConsumerSetting({ notifications_enabled: next });

    persist
      .then((result) => {
        setSetting(result);
        setOverride(null);
      })
      .catch((error) => {
        setOverride(null); // revert to the last known-good value
        if (error instanceof ApiError && error.status === 401) forceLogout();
      });
  }, [notificationsEnabled, setting]);

  return { notificationsEnabled, toggleNotifications };
}
