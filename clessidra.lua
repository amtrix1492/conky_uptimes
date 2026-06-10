require 'cairo'
require 'cairo_xlib'

-- Lettura dei secondi reali dal file di sistema /proc/uptime
local function get_real_uptime_secs()
    local file = io.open("/proc/uptime", "r")
    if file then
        local content = file:read("*all")
        file:close()
        local uptime = string.match(content, "^([%d%.]+)")
        return math.floor(tonumber(uptime) or 0)
    end
    return 0
end

-- Funzione di supporto per disegnare una mini clessidra piena (indicatore orario)
local function draw_mini_hourglass(cr, x, y, r, g, b, a)
    local mw = 6  -- Semi-larghezza mini clessidra
    local mh = 8  -- Semi-altezza mini clessidra
    local mn = 1.5 -- Larghezza collo
    
    cairo_save(cr)
    
    -- Disegno del contorno e del riempimento totale della sabbia d'oro
    cairo_set_source_rgba(cr, r, g, b, a)
    cairo_move_to(cr, x - mw, y - mh)
    cairo_line_to(cr, x + mw, y - mh)
    cairo_curve_to(cr, x + mw, y - mh/2, x + mn, y - mh/4, x + mn, y)
    cairo_curve_to(cr, x + mn, y + mh/4, x + mw, y + mh/2, x + mw, y + mh)
    cairo_line_to(cr, x - mw, y + mh)
    cairo_curve_to(cr, x - mw, y + mh/2, x - mn, y + mh/4, x - mn, y)
    cairo_curve_to(cr, x - mn, y - mh/4, x - mw, y - mh/2, x - mw, y - mh)
    cairo_close_path(cr)
    cairo_fill(cr)
    
    -- Disegno del bordo metallico sottile intorno alla mini clessidra
    cairo_set_source_rgba(cr, 0.85, 0.87, 0.90, 0.9)
    cairo_set_line_width(cr, 1)
    cairo_move_to(cr, x - mw, y - mh)
    cairo_line_to(cr, x + mw, y - mh)
    cairo_curve_to(cr, x + mw, y - mh/2, x + mn, y - mh/4, x + mn, y)
    cairo_curve_to(cr, x + mn, y + mh/4, x + mw, y + mh/2, x + mw, y + mh)
    cairo_line_to(cr, x - mw, y + mh)
    cairo_curve_to(cr, x - mw, y + mh/2, x - mn, y + mh/4, x - mn, y)
    cairo_curve_to(cr, x - mn, y - mh/4, x - mw, y - mh/2, x - mw, y - mh)
    cairo_close_path(cr)
    cairo_stroke(cr)
    
    cairo_restore(cr)
end

function conky_clessidra_main()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    
    -- IMPOSTAZIONI GEOMETRIA CLESSIDRA PRINCIPALE
    local cx = 75      -- Centro X della clessidra nella finestra (modificato sotto per l'avviso lungo)
    local cy = 60      -- Centro Y della clessidra nella finestra
    local w = 40       -- Larghezza massima dei bulbi
    local h = 40       -- Altezza di ciascun bulbo (totale clessidra = h*2)
    local neck = 6     -- Larghezza del collo centrale
    
    -- CONFIGURAZIONE TEMPO (1 ora = 3600 secondi)
    local max_time = 3600
    local real_uptime = get_real_uptime_secs()
    
    -- CALCOLO STATISTICHE
    local ciclo = math.floor(real_uptime / max_time)
    local secondi_correnti = real_uptime % max_time
    local minuti = math.floor(secondi_correnti / 60)
    local pct = secondi_correnti / max_time 
    
    -- IDENTIFICAZIONE SE IL CICLO È DISPARI (Clessidra capovolta)
    local is_inverted = (ciclo % 2 == 1)
    local current_angle = is_inverted and math.pi or 0

    -- Se siamo in stato di avviso estendiamo virtualmente la larghezza della finestra Conky 
    -- per evitare che il testo lungo venga tagliato a destra. Centriamo la clessidra a X=150.
    if ciclo >= 5 then
        cx = 150
    end

    -- 1. APPLICHIAMO LA ROTAZIONE ALLA STRUTTURA ESTERNA
    cairo_save(cr)
    cairo_translate(cr, cx, cy)
    cairo_rotate(cr, current_angle)
    cairo_translate(cr, -cx, -cy)

    -- COLORI
    local sand_r, sand_g, sand_b, sand_a = 1.0, 0.75, 0.0, 0.65
    local frame_r, frame_g, frame_b, frame_a = 0.85, 0.87, 0.90, 0.95

    -- DISEGNO VETRO CLESSIDRA
    cairo_set_source_rgba(cr, frame_r, frame_g, frame_b, frame_a) 
    cairo_set_line_width(cr, 2)
    cairo_move_to(cr, cx - w, cy - h)
    cairo_line_to(cr, cx + w, cy - h)
    cairo_curve_to(cr, cx + w, cy - h/2, cx + neck, cy - h/4, cx + neck, cy)
    cairo_curve_to(cr, cx + neck, cy + h/4, cx + w, cy + h/2, cx + w, cy + h)
    cairo_line_to(cr, cx - w, cy + h)
    cairo_curve_to(cr, cx - w, cy + h/2, cx - neck, cy + h/4, cx - neck, cy)
    cairo_curve_to(cr, cx - neck, cy - h/4, cx - w, cy - h/2, cx - w, cy - h)
    cairo_stroke(cr)

    -- ELEMENTI ASIMMETRICI (Base e pilastro)
    cairo_set_line_width(cr, 4)
    cairo_move_to(cr, cx - w - 8, cy + h + 2)
    cairo_line_to(cr, cx + w + 8, cy + h + 2)
    cairo_stroke(cr)
    
    cairo_set_line_width(cr, 3)
    cairo_move_to(cr, cx - w - 6, cy - h)
    cairo_line_to(cr, cx - w - 6, cy + h)
    cairo_stroke(cr)
    cairo_restore(cr) 

    -- 2. DISEGNO DELLA SABBIA IN COORDINATE REALI DELLO SCHERMO
    local function clip_bulbo_inferiore()
        cairo_move_to(cr, cx - neck, cy)
        cairo_curve_to(cr, cx - neck, cy + h/4, cx - w, cy + h/2, cx - w, cy + h)
        cairo_line_to(cr, cx + w, cy + h)
        cairo_curve_to(cr, cx + w, cy + h/2, cx + neck, cy + h/4, cx + neck, cy)
        cairo_close_path(cr)
        cairo_clip(cr)
    end

    local function clip_bulbo_superiore()
        cairo_move_to(cr, cx - w, cy - h)
        cairo_line_to(cr, cx + w, cy - h)
        cairo_curve_to(cr, cx + w, cy - h/2, cx + neck, cy - h/4, cx + neck, cy)
        cairo_line_to(cr, cx - neck, cy)
        cairo_curve_to(cr, cx - neck, cy - h/4, cx - w, cy - h/2, cx - w, cy - h)
        cairo_close_path(cr)
        cairo_clip(cr)
    end

    if pct > 0 then
        cairo_save(cr)
        clip_bulbo_inferiore()
        local fill_height = h * pct
        local fill_y = (cy + h) - fill_height
        cairo_rectangle(cr, cx - w, fill_y, w * 2, fill_height)
        cairo_set_source_rgba(cr, sand_r, sand_g, sand_b, sand_a)
        cairo_fill(cr)
        cairo_restore(cr)
    end
    
    if pct < 1 then
        cairo_save(cr)
        clip_bulbo_superiore()
        local empty_height = h * pct
        local sand_y = (cy - h) + empty_height
        local sand_height = h - empty_height
        cairo_rectangle(cr, cx - w, sand_y, w * 2, sand_height)
        cairo_set_source_rgba(cr, sand_r, sand_g, sand_b, sand_a)
        cairo_fill(cr)
        cairo_restore(cr)
    end

    -- 3. FILO DI SABBIA VERTICALE
    if pct < 1 and pct > 0 then
        cairo_save(cr)
        local fill_height = h * pct
        local target_y = (cy + h) - fill_height
        cairo_set_source_rgba(cr, sand_r, sand_g, sand_b, 0.85)
        cairo_set_line_width(cr, 2)
        cairo_move_to(cr, cx, cy)
        cairo_line_to(cr, cx, target_y)
        cairo_stroke(cr)
        cairo_restore(cr)
    end

    -- 4. DISEGNO DEGLI INDICATORI CENTRATI (MAX 4 MINI CLESSIDRE)
    local ty = cy + h + 25 
    local spacing = 16    
    local mini_clessidre_da_disegnare = math.min(ciclo, 4)
    
    if mini_clessidre_da_disegnare > 0 then
        -- Calcolo della X iniziale affinché il blocco totale delle icone sia centrato rispetto a 'cx'
        local larghezza_totale_gruppo = (mini_clessidre_da_disegnare - 1) * spacing
        local start_x = cx - (larghezza_totale_gruppo / 2)
        
        for i = 1, mini_clessidre_da_disegnare do
            local mini_x = start_x + (i - 1) * spacing
            draw_mini_hourglass(cr, mini_x, ty - 4, sand_r, sand_g, sand_b, 0.8)
        end
    end

    -- 5. DISEGNO DEL TESTO (MINUTI CORRENTI O AVVISO CRITICO)
    cairo_select_font_face(cr, "DejaVu Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
    
    if ciclo >= 5 then
        -- STATO DI ALLERTA: Mostra il testo personalizzato rosso
        cairo_set_font_size(cr, 10)
        local testo_allerta = "ATTENZIONE SONO ACCESO DA TROPPO TEMPO"
        
        local extents = cairo_text_extents_t:create()
        cairo_text_extents(cr, testo_allerta, extents)
        local tx = cx - (extents.width / 2 + extents.x_bearing)
        local ty_allerta = ty + 20 -- Lo posizioniamo un livello più in basso rispetto alle icone
        
        -- Ombra scura
        cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.7)
        cairo_move_to(cr, tx + 1, ty_allerta + 1)
        cairo_show_text(cr, testo_allerta)

        -- Testo rosso acceso (#FF3333)
        cairo_set_source_rgba(cr, 1.0, 0.2, 0.2, 1.0)
        cairo_move_to(cr, tx, ty_allerta)
        cairo_show_text(cr, testo_allerta)
    else
        -- STATO REGOLARE: Mostra i minuti accanto o sotto le clessidre
        cairo_set_font_size(cr, 11)
        local testo_minuti = string.format("%dm", minuti)
        
        local extents = cairo_text_extents_t:create()
        cairo_text_extents(cr, testo_minuti, extents)
        
        -- Se ci sono icone, mettiamo i minuti centrati sotto di esse, altrimenti al centro
        local tx = cx - (extents.width / 2 + extents.x_bearing)
        local ty_minuti = (ciclo > 0) and (ty + 16) or ty
        
        -- Ombra
        cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.6)
        cairo_move_to(cr, tx + 1, ty_minuti + 1)
        cairo_show_text(cr, testo_minuti)

        -- Testo bianco
        cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 1.0)
        cairo_move_to(cr, tx, ty_minuti)
        cairo_show_text(cr, testo_minuti)
    end

    -- Pulizia memoria cairo
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
