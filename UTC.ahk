; Time conversion hotkeys - UTC, IST, and Pacific (PST/PDT with automatic DST)
; Uses A_NowUTC so the script works regardless of system timezone.
;
; Hotkeys:
;   Alt+U       → paste UTC date+time
;   Alt+I       → paste IST date+time
;   Alt+P       → paste Pacific date+time (auto DST)
;   Alt+Shift+U → paste UTC date only
;   Alt+Shift+I → paste IST date only
;   Alt+Shift+P → paste Pacific date only (auto DST)

#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------------------------------------------------------------------------
; Check if US Pacific Time is currently observing DST.
; DST starts: 2nd Sunday of March at 2:00 AM local
; DST ends:   1st Sunday of November at 2:00 AM local
; ---------------------------------------------------------------------------
IsPacificDST() {
    utc := A_NowUTC
    ; Use tentative PST (UTC-8) to determine the calendar date in Pacific zone
    pst := DateAdd(utc, -8, "Hours")

    yr := FormatTime(pst, "yyyy")
    mn := Integer(FormatTime(pst, "M"))
    dy := Integer(FormatTime(pst, "d"))
    hr := Integer(FormatTime(pst, "H"))

    ; April – October: always DST
    if (mn >= 4 && mn <= 10)
        return true
    ; December, January, February: never DST
    if (mn <= 2 || mn == 12)
        return false

    ; March: DST starts on 2nd Sunday at 2:00 AM
    if (mn == 3) {
        firstOfMonth := yr "0301000000"
        wday := Integer(FormatTime(firstOfMonth, "WDay"))  ; 1=Sun … 7=Sat
        firstSun := (wday == 1) ? 1 : (8 - wday + 1)
        secondSun := firstSun + 7
        return (dy > secondSun) || (dy == secondSun && hr >= 2)
    }

    ; November: DST ends on 1st Sunday at 2:00 AM PDT (= 1:00 AM PST)
    if (mn == 11) {
        firstOfMonth := yr "1101000000"
        wday := Integer(FormatTime(firstOfMonth, "WDay"))
        firstSun := (wday == 1) ? 1 : (8 - wday + 1)
        return (dy < firstSun) || (dy == firstSun && hr < 1)
    }

    return false
}

; Alt+U: Paste current UTC date+time
!u:: {
    utc := A_NowUTC
    A_Clipboard := FormatTime(utc, "yyyy-MM-dd HH:mm:ss")
    Send "^v"
}

; Alt+I: Paste current IST date+time (UTC+5:30)
!i:: {
    ist := DateAdd(A_NowUTC, 5, "Hours")
    ist := DateAdd(ist, 30, "Minutes")
    A_Clipboard := FormatTime(ist, "yyyy-MM-dd HH:mm:ss")
    Send "^v"
}

; Alt+Shift+I: Paste current IST date only
!+i:: {
    ist := DateAdd(A_NowUTC, 5, "Hours")
    ist := DateAdd(ist, 30, "Minutes")
    A_Clipboard := FormatTime(ist, "yyyy-MM-dd")
    Send "^v"
}

; Alt+P: Paste current Pacific (PST/PDT) date+time — auto DST
!p:: {
    offset := IsPacificDST() ? -7 : -8
    pacific := DateAdd(A_NowUTC, offset, "Hours")
    A_Clipboard := FormatTime(pacific, "yyyy-MM-dd HH:mm:ss")
    Send "^v"
}

; Alt+Shift+U: Paste current UTC date only
!+u:: {
    utc := A_NowUTC
    A_Clipboard := FormatTime(utc, "yyyy-MM-dd")
    Send "^v"
}

; Alt+Shift+P: Paste current Pacific (PST/PDT) date only — auto DST
!+p:: {
    offset := IsPacificDST() ? -7 : -8
    pacific := DateAdd(A_NowUTC, offset, "Hours")
    A_Clipboard := FormatTime(pacific, "yyyy-MM-dd")
    Send "^v"
}