.pragma library

var ACCENT_TEAL = { hi: "128,224,224", mid: "57,197,187", lo: "42,138,138", dk: "58,106,106", edge: "#c0f4f4", edgeGlow: "150,240,240", glowHi: "210,255,255", glowMid: "150,245,245" }
var ACCENT_RED  = { hi: "240,128,128", mid: "224,80,80",  lo: "204,68,68",  dk: "106,42,42",  edge: "#ffc0c0", edgeGlow: "255,150,150", glowHi: "255,210,210", glowMid: "255,150,150" }

function facetShape(ctx, w, h, cut) {
    ctx.beginPath()
    ctx.moveTo(cut, 0); ctx.lineTo(w, 0)
    ctx.lineTo(w, h - cut); ctx.lineTo(w - cut, h)
    ctx.lineTo(0, h); ctx.lineTo(0, cut); ctx.closePath()
}

function paintFacetPill(ctx, w, h, hp, cut, accent) {
    ctx.clearRect(0, 0, w, h)
    if (cut === undefined) cut = 5
    if (accent === undefined) accent = ACCENT_TEAL

    function drawShape() { facetShape(ctx, w, h, cut) }

    drawShape()
    var base = ctx.createLinearGradient(0, 0, 0, h)
    base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
    base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
    ctx.fillStyle = base; ctx.fill()

    if (hp > 0) {
        drawShape()
        var accentFill = ctx.createLinearGradient(0, 0, 0, h)
        accentFill.addColorStop(0, "rgb(" + accent.hi + ")"); accentFill.addColorStop(0.08, "rgb(" + accent.mid + ")")
        accentFill.addColorStop(0.5, "rgb(" + accent.lo + ")"); accentFill.addColorStop(1.0, "rgb(" + accent.dk + ")")
        ctx.globalAlpha = hp; ctx.fillStyle = accentFill; ctx.fill(); ctx.globalAlpha = 1.0
    }

    if (hp > 0) {
        drawShape()
        ctx.save()
        ctx.clip()
        var innerGlow = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.75)
        innerGlow.addColorStop(0, "rgba(" + accent.glowHi + "," + (hp * 0.5) + ")")
        innerGlow.addColorStop(0.6, "rgba(" + accent.glowMid + "," + (hp * 0.22) + ")")
        innerGlow.addColorStop(1, "rgba(" + accent.glowMid + ",0.0)")
        ctx.fillStyle = innerGlow
        ctx.fillRect(0, 0, w, h)
        ctx.restore()
    }

    ctx.beginPath()
    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
    gloss.addColorStop(0, "rgba(255,255,255," + (0.12 + hp * 0.2) + ")")
    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
    ctx.fillStyle = gloss; ctx.fill()

    drawShape()
    ctx.strokeStyle = hp > 0.5 ? accent.edge : "#646464"
    ctx.lineWidth = 1
    ctx.stroke()

    if (hp > 0) {
        drawShape()
        ctx.strokeStyle = "rgba(" + accent.edgeGlow + "," + (hp * 0.95) + ")"
        ctx.lineWidth = 1.4
        ctx.stroke()
    }
}

function paintFacetSlant(ctx, w, h, hp, slant, accent) {
    ctx.clearRect(0, 0, w, h)
    if (accent === undefined) accent = ACCENT_TEAL

    function drawShape() {
        ctx.beginPath()
        ctx.moveTo(0, 0); ctx.lineTo(w, 0)
        ctx.lineTo(w - slant, h); ctx.lineTo(0, h)
        ctx.closePath()
    }

    drawShape()
    var base = ctx.createLinearGradient(0, 0, 0, h)
    base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
    base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
    ctx.fillStyle = base; ctx.fill()

    if (hp > 0) {
        drawShape()
        var accentFill = ctx.createLinearGradient(0, 0, 0, h)
        accentFill.addColorStop(0, "rgb(" + accent.hi + ")"); accentFill.addColorStop(0.08, "rgb(" + accent.mid + ")")
        accentFill.addColorStop(0.5, "rgb(" + accent.lo + ")"); accentFill.addColorStop(1.0, "rgb(" + accent.dk + ")")
        ctx.globalAlpha = hp; ctx.fillStyle = accentFill; ctx.fill(); ctx.globalAlpha = 1.0
    }

    if (hp > 0) {
        drawShape()
        ctx.save()
        ctx.clip()
        var innerGlow = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.75)
        innerGlow.addColorStop(0, "rgba(" + accent.glowHi + "," + (hp * 0.5) + ")")
        innerGlow.addColorStop(0.6, "rgba(" + accent.glowMid + "," + (hp * 0.22) + ")")
        innerGlow.addColorStop(1, "rgba(" + accent.glowMid + ",0.0)")
        ctx.fillStyle = innerGlow
        ctx.fillRect(0, 0, w, h)
        ctx.restore()
    }

    ctx.save()
    drawShape()
    ctx.clip()
    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.55)
    gloss.addColorStop(0, "rgba(255,255,255," + (0.22 + hp * 0.18) + ")")
    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
    ctx.fillStyle = gloss
    ctx.fillRect(0, 0, w, h * 0.55)
    ctx.restore()

    drawShape()
    ctx.strokeStyle = hp > 0.5 ? accent.edge : "#646464"
    ctx.lineWidth = 1
    ctx.stroke()

    if (hp > 0) {
        drawShape()
        ctx.strokeStyle = "rgba(" + accent.edgeGlow + "," + (hp * 0.95) + ")"
        ctx.lineWidth = 1.4
        ctx.stroke()
    }
}

function paintWsPill(ctx, w, h, activeProgress, hoverProgress, pulse) {
    ctx.clearRect(0, 0, w, h)
    var cut = 6
    var ap = activeProgress
    var hp = hoverProgress
    var tealAmount = Math.max(ap, hp * (1.0 - ap))
    var glowAmount = Math.max(tealAmount, ap * pulse * 0.6)

    function drawShape() { facetShape(ctx, w, h, cut) }

    drawShape()
    var base = ctx.createLinearGradient(0, 0, 0, h)
    base.addColorStop(0, "#3d3d3d"); base.addColorStop(0.08, "#2a2a2a")
    base.addColorStop(0.5, "#303030"); base.addColorStop(1.0, "#3a3a3a")
    ctx.fillStyle = base; ctx.fill()

    if (tealAmount > 0) {
        drawShape()
        var teal = ctx.createLinearGradient(0, 0, 0, h)
        teal.addColorStop(0, "#80e0e0"); teal.addColorStop(0.08, "#39c5bb")
        teal.addColorStop(0.5, "#2a8a8a"); teal.addColorStop(1.0, "#3a6a6a")
        ctx.globalAlpha = tealAmount; ctx.fillStyle = teal; ctx.fill(); ctx.globalAlpha = 1.0
    }

    if (glowAmount > 0) {
        drawShape()
        ctx.save()
        ctx.clip()
        var innerGlow = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, Math.max(w, h) * 0.75)
        innerGlow.addColorStop(0, "rgba(210,255,255," + (glowAmount * 0.55) + ")")
        innerGlow.addColorStop(0.6, "rgba(150,245,245," + (glowAmount * 0.25) + ")")
        innerGlow.addColorStop(1, "rgba(150,245,245,0.0)")
        ctx.fillStyle = innerGlow
        ctx.fillRect(0, 0, w, h)
        ctx.restore()
    }

    ctx.beginPath()
    ctx.moveTo(cut, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.62)
    ctx.lineTo(0, h * 0.62); ctx.lineTo(0, cut); ctx.closePath()
    var gloss = ctx.createLinearGradient(0, 0, 0, h * 0.62)
    gloss.addColorStop(0, "rgba(255,255,255," + (0.30 + tealAmount * 0.24) + ")")
    gloss.addColorStop(1, "rgba(255,255,255,0.00)")
    ctx.fillStyle = gloss; ctx.fill()

    drawShape()
    ctx.strokeStyle = tealAmount > 0.5 ? "#c0f4f4" : "#646464"
    ctx.lineWidth = 1
    ctx.stroke()

    if (ap > 0) {
        drawShape()
        ctx.strokeStyle = "rgba(200,250,250," + (ap * (0.7 + pulse * 0.3)) + ")"
        ctx.lineWidth = 1.4
        ctx.stroke()
    }
}
