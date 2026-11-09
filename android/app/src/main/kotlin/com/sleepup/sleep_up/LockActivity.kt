package com.sleepup.sleep_up

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Kilit saatinde engelli bir uygulamanın üstüne açılan tam ekran.
 * Tasarımdaki "Kilit ekranı" artboard'unun native karşılığı.
 * Arayüz koddan kurulur; ek XML/kütüphane gerektirmez.
 */
class LockActivity : Activity() {

    private lateinit var store: LockStore
    private lateinit var clock: TextView
    private lateinit var body: TextView
    private lateinit var actions: LinearLayout
    private val handler = Handler(Looper.getMainLooper())
    private val hm = SimpleDateFormat("HH:mm", Locale("tr"))

    private val refresher = object : Runnable {
        override fun run() {
            if (!store.isLockActive()) { finish(); return }
            render()
            handler.postDelayed(this, 15_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        store = LockStore(this)
        window.statusBarColor = BG
        window.navigationBarColor = BG
        setContentView(buildUi())
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresher)
    }

    override fun onPause() {
        handler.removeCallbacks(refresher)
        super.onPause()
    }

    @Deprecated("Geri tuşu kilitli uygulamaya değil ana ekrana götürür.")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        finish()
    }

    // ---------- Arayüz ----------

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
    ).toInt()

    private fun round(color: Int, radiusDp: Int, stroke: Int? = null) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
        stroke?.let { setStroke(dp(1), it) }
    }

    private fun text(size: Float, color: Int, bold: Boolean = false) = TextView(this).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        setTextColor(color)
        gravity = Gravity.CENTER
        if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    private fun button(label: String, primary: Boolean, onClick: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        setTextColor(if (primary) ON_AMBER else TEXT)
        background = if (primary) round(AMBER, 16) else round(Color.TRANSPARENT, 16, LINE)
        minHeight = dp(52)
        stateListAnimator = null
        setOnClickListener { onClick() }
    }

    private fun lp(topDp: Int = 0) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
    ).apply { topMargin = dp(topDp) }

    private fun buildUi(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(BG)
            setPadding(dp(28), dp(96), dp(28), dp(40))
        }
        val moon = text(40f, AMBER).apply {
            text = "☾"
            background = round(SURFACE, 48)
            layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
        }
        clock = text(56f, TEXT, bold = true)
        val title = text(24f, TEXT, bold = true).apply { text = "Telefonun uyuyor" }
        body = text(15f, MUTED).apply { setLineSpacing(0f, 1.3f) }
        actions = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }

        root.addView(moon)
        root.addView(clock, lp(20))
        root.addView(title, lp(12))
        root.addView(body, lp(12))
        root.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f)) // boşluk
        root.addView(actions, lp())
        showIdleActions()
        return root
    }

    private fun render() {
        val now = System.currentTimeMillis()
        clock.text = hm.format(Date(now))
        val until = store.lockUntil(now)
        val leftMin = ((until - now) / 60_000).coerceAtLeast(0)
        body.text = "Bu uygulama ${hm.format(Date(until))}'e kadar kilitli.\n" +
            "Uyumak için ${leftMin / 60} saat ${leftMin % 60} dakikan var."
    }

    private fun showIdleActions() {
        actions.removeAllViews()
        val tip = text(14f, SOFT).apply {
            gravity = Gravity.START
            text = "Zihnin hâlâ meşgulse: aklındakini bir kâğıda yaz, telefonu yatağın dışına bırak."
            background = round(SURFACE, 18)
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }
        actions.addView(tip, lp())
        actions.addView(button("Ana ekrana dön", primary = true) { goHome() }, lp(10))

        val s = store.schedule()
        val left = (s?.emergencyPerNight ?: 0) - store.emergencyUsedTonight()
        if (left > 0) {
            actions.addView(button("Acil açma (bu gece $left hak)", primary = false) { showAsk() }, lp(10))
        }
    }

    private fun showAsk() {
        actions.removeAllViews()
        val label = text(14f, SOFT).apply {
            gravity = Gravity.START
            text = "Devam etmek için şunu yaz:\n\"$PHRASE\""
        }
        val input = EditText(this).apply {
            hint = "Buraya yaz"
            setHintTextColor(MUTED)
            setTextColor(TEXT)
            inputType = InputType.TYPE_CLASS_TEXT
            background = round(SURFACE, 14, LINE)
            setPadding(dp(14), dp(14), dp(14), dp(14))
        }
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val cancel = button("Vazgeç, uyu", primary = true) { showIdleActions() }
        val open = button("5 dk aç", primary = false) {
            if (store.useEmergency(5)) finish() else showIdleActions()
        }.apply { isEnabled = false; alpha = 0.5f }
        input.addTextChangedListener(object : TextWatcher {
            override fun afterTextChanged(e: Editable?) {
                val ok = e.toString().trim().lowercase(Locale("tr")) == PHRASE
                open.isEnabled = ok
                open.alpha = if (ok) 1f else 0.5f
            }
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
        })
        row.addView(cancel, LinearLayout.LayoutParams(0, dp(52), 1f).apply { marginEnd = dp(10) })
        row.addView(open, LinearLayout.LayoutParams(0, dp(52), 1f))
        actions.addView(label, lp())
        actions.addView(input, lp(10))
        actions.addView(row, lp(12))
    }

    companion object {
        const val EXTRA_BLOCKED_PKG = "blocked_pkg"
        const val PHRASE = "uyumam gerekiyor ama bu acil"
        private val BG = Color.parseColor("#07080F")
        private val SURFACE = Color.parseColor("#171A2E")
        private val LINE = Color.parseColor("#2E3352")
        private val TEXT = Color.parseColor("#EEF0FA")
        private val SOFT = Color.parseColor("#C9CCE0")
        private val MUTED = Color.parseColor("#A2A7C4")
        private val AMBER = Color.parseColor("#F4B860")
        private val ON_AMBER = Color.parseColor("#1A1406")
    }
}
