package dev.sumbee

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import dev.sumbee.ui.App
import dev.sumbee.ui.SumbeeTheme
import dev.sumbee.ui.SessionViewModel

class MainActivity : ComponentActivity() {

    private val vm: SessionViewModel by viewModels { SessionViewModel.factory(application) }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen() // no keep-on-screen condition (IMPLEMENTATION.md §4.5)
        super.onCreate(savedInstanceState)
        // The ground is always light, so the system bars always use dark icons.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT),
        )
        // FR-3.5: the clock pauses while the app isn't visible.
        lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                when (event) {
                    Lifecycle.Event.ON_START -> vm.onVisible()
                    Lifecycle.Event.ON_STOP -> vm.onHidden()
                    else -> Unit
                }
            },
        )
        setContent {
            SumbeeTheme { App(vm) }
        }
    }
}
