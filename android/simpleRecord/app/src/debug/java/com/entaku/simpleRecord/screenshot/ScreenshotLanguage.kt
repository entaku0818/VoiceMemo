package com.entaku.simpleRecord.screenshot

import java.util.Locale

enum class ScreenshotLanguage(val code: String, val locale: Locale) {
    JAPANESE("ja", Locale.JAPANESE),
    ENGLISH("en", Locale.ENGLISH),
    GERMAN("de", Locale.GERMAN),
    SPANISH("es", Locale("es")),
    FRENCH("fr", Locale.FRENCH),
    ITALIAN("it", Locale.ITALIAN),
    PORTUGUESE("pt", Locale("pt")),
    RUSSIAN("ru", Locale("ru")),
    TURKISH("tr", Locale("tr")),
    VIETNAMESE("vi", Locale("vi")),
    CHINESE_SIMPLIFIED("zh_hans", Locale.SIMPLIFIED_CHINESE),
    CHINESE_TRADITIONAL("zh_hant", Locale.TRADITIONAL_CHINESE),
}

enum class ScreenshotScreen {
    RECORDINGS_LIST,
    RECORDING,
    PLAYBACK,
    PLAYLIST,
}

fun ScreenshotLanguage.caption(screen: ScreenshotScreen): String = when (this) {
    ScreenshotLanguage.JAPANESE -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "録音を\nかんたん管理"
        ScreenshotScreen.RECORDING      -> "ワンタップで\n録音開始"
        ScreenshotScreen.PLAYBACK       -> "いつでも\n聴き返せる"
        ScreenshotScreen.PLAYLIST       -> "プレイリストで\n整理する"
    }
    ScreenshotLanguage.ENGLISH -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Manage Your\nRecordings"
        ScreenshotScreen.RECORDING      -> "Record with\nOne Tap"
        ScreenshotScreen.PLAYBACK       -> "Play Back\nAnytime"
        ScreenshotScreen.PLAYLIST       -> "Organize with\nPlaylists"
    }
    ScreenshotLanguage.GERMAN -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Aufnahmen\nverwalten"
        ScreenshotScreen.RECORDING      -> "Mit einem Tap\naufnehmen"
        ScreenshotScreen.PLAYBACK       -> "Jederzeit\nabspielen"
        ScreenshotScreen.PLAYLIST       -> "Mit Playlists\norganisieren"
    }
    ScreenshotLanguage.SPANISH -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Gestiona tus\ngrabaciones"
        ScreenshotScreen.RECORDING      -> "Graba con\nun toque"
        ScreenshotScreen.PLAYBACK       -> "Reproduce\ncuando quieras"
        ScreenshotScreen.PLAYLIST       -> "Organiza con\nplaylists"
    }
    ScreenshotLanguage.FRENCH -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Gérez vos\nenregistrements"
        ScreenshotScreen.RECORDING      -> "Enregistrez en\nun tap"
        ScreenshotScreen.PLAYBACK       -> "Écoutez\nn'importe quand"
        ScreenshotScreen.PLAYLIST       -> "Organisez avec\ndes playlists"
    }
    ScreenshotLanguage.ITALIAN -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Gestisci le tue\nregistrazioni"
        ScreenshotScreen.RECORDING      -> "Registra con\nun tap"
        ScreenshotScreen.PLAYBACK       -> "Riproduci\nquando vuoi"
        ScreenshotScreen.PLAYLIST       -> "Organizza con\nle playlist"
    }
    ScreenshotLanguage.PORTUGUESE -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Gerencie suas\ngravações"
        ScreenshotScreen.RECORDING      -> "Grave com\num toque"
        ScreenshotScreen.PLAYBACK       -> "Reproduza\na qualquer hora"
        ScreenshotScreen.PLAYLIST       -> "Organize com\nplaylists"
    }
    ScreenshotLanguage.RUSSIAN -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Управляйте\nзаписями"
        ScreenshotScreen.RECORDING      -> "Записывайте\nодним касанием"
        ScreenshotScreen.PLAYBACK       -> "Слушайте\nв любое время"
        ScreenshotScreen.PLAYLIST       -> "Организуйте\nплейлисты"
    }
    ScreenshotLanguage.TURKISH -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Kayıtlarınızı\nyönetin"
        ScreenshotScreen.RECORDING      -> "Tek dokunuşla\nkaydedin"
        ScreenshotScreen.PLAYBACK       -> "İstediğiniz\nzaman dinleyin"
        ScreenshotScreen.PLAYLIST       -> "Oynatma listesiyle\ndüzenleyin"
    }
    ScreenshotLanguage.VIETNAMESE -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "Quản lý\nbản ghi âm"
        ScreenshotScreen.RECORDING      -> "Ghi âm chỉ\nmột chạm"
        ScreenshotScreen.PLAYBACK       -> "Nghe lại\nbất cứ lúc nào"
        ScreenshotScreen.PLAYLIST       -> "Sắp xếp với\ndanh sách phát"
    }
    ScreenshotLanguage.CHINESE_SIMPLIFIED -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "管理您的\n录音文件"
        ScreenshotScreen.RECORDING      -> "轻点一下\n即可录音"
        ScreenshotScreen.PLAYBACK       -> "随时随地\n回放录音"
        ScreenshotScreen.PLAYLIST       -> "用播放列表\n整理录音"
    }
    ScreenshotLanguage.CHINESE_TRADITIONAL -> when (screen) {
        ScreenshotScreen.RECORDINGS_LIST -> "管理您的\n錄音檔案"
        ScreenshotScreen.RECORDING      -> "輕點一下\n即可錄音"
        ScreenshotScreen.PLAYBACK       -> "隨時隨地\n回放錄音"
        ScreenshotScreen.PLAYLIST       -> "用播放清單\n整理錄音"
    }
}

fun ScreenshotLanguage.subtitle(): String = when (this) {
    ScreenshotLanguage.JAPANESE          -> "シンプル録音"
    ScreenshotLanguage.ENGLISH           -> "Simple Record"
    ScreenshotLanguage.GERMAN            -> "Einfache Aufnahme"
    ScreenshotLanguage.SPANISH           -> "Grabación Simple"
    ScreenshotLanguage.FRENCH            -> "Enregistrement Simple"
    ScreenshotLanguage.ITALIAN           -> "Registrazione Semplice"
    ScreenshotLanguage.PORTUGUESE        -> "Gravação Simples"
    ScreenshotLanguage.RUSSIAN           -> "Простая Запись"
    ScreenshotLanguage.TURKISH           -> "Basit Kayıt"
    ScreenshotLanguage.VIETNAMESE        -> "Ghi Âm Đơn Giản"
    ScreenshotLanguage.CHINESE_SIMPLIFIED  -> "简单录音"
    ScreenshotLanguage.CHINESE_TRADITIONAL -> "簡單錄音"
}
