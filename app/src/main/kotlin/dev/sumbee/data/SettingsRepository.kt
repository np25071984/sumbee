package dev.sumbee.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dev.sumbee.model.Operation
import dev.sumbee.model.SessionConfig
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

/** The last-used Setup, remembered between runs (SPEC.md FR-1.6). Nothing else is ever stored. */
interface SettingsStore {
    val config: Flow<SessionConfig>
    suspend fun save(config: SessionConfig)
}

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

/** [SettingsStore] on DataStore preferences, on the device only (IMPLEMENTATION.md §4.3). */
class SettingsRepository(context: Context) : SettingsStore {

    private val store = context.applicationContext.settingsDataStore

    override val config: Flow<SessionConfig> = store.data
        .catch { emit(androidx.datastore.preferences.core.emptyPreferences()) }
        .map { prefs ->
            val defaults = SessionConfig()
            SessionConfig(
                name = prefs[NAME] ?: defaults.name,
                maxNumber = prefs[MAX] ?: defaults.maxNumber,
                ops = prefs[OPS]?.mapNotNull { name -> Operation.entries.find { it.name == name } }?.toSet()
                    ?: defaults.ops,
                cardCount = prefs[COUNT] ?: defaults.cardCount,
            ).sanitized()
        }

    override suspend fun save(config: SessionConfig) {
        store.edit { prefs ->
            prefs[NAME] = config.name
            prefs[MAX] = config.maxNumber
            prefs[OPS] = config.ops.map { it.name }.toSet()
            prefs[COUNT] = config.cardCount
        }
    }

    private companion object {
        val NAME = stringPreferencesKey("name")
        val MAX = intPreferencesKey("max")
        val OPS = stringSetPreferencesKey("ops")
        val COUNT = intPreferencesKey("count")
    }
}
