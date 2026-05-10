local stringify = (require "pandoc.utils").stringify

--------------------------------------------------------------------------------
-- Callout definitions: icon, border colour (left stripe), background fill
-- Colours closely match Obsidian's default callout palette.
--------------------------------------------------------------------------------
local callout_defs = {
    note      = { icon = "📝", border = "448AFF", bg = "E8F0FE" },
    tip       = { icon = "💡", border = "00BFA5", bg = "E0F2F1" },
    hint      = { icon = "💡", border = "00BFA5", bg = "E0F2F1" },
    important = { icon = "❗", border = "00B0FF", bg = "E1F5FE" },
    warning   = { icon = "⚠️", border = "FF9100", bg = "FFF3E0" },
    caution   = { icon = "⚠️", border = "FF9100", bg = "FFF3E0" },
    danger    = { icon = "🔴", border = "FB464C", bg = "FFEBEE" },
    info      = { icon = "ℹ️", border = "448AFF", bg = "E8F0FE" },
    abstract  = { icon = "📋", border = "00B0FF", bg = "E1F5FE" },
    summary   = { icon = "📋", border = "00B0FF", bg = "E1F5FE" },
    tldr      = { icon = "📋", border = "00B0FF", bg = "E1F5FE" },
    todo      = { icon = "☑️", border = "448AFF", bg = "E8F0FE" },
    success   = { icon = "✅", border = "00C853", bg = "E8F5E9" },
    check     = { icon = "✅", border = "00C853", bg = "E8F5E9" },
    done      = { icon = "✅", border = "00C853", bg = "E8F5E9" },
    question  = { icon = "❓", border = "ECAF00", bg = "FFF8E1" },
    help      = { icon = "❓", border = "ECAF00", bg = "FFF8E1" },
    faq       = { icon = "❓", border = "ECAF00", bg = "FFF8E1" },
    failure   = { icon = "❌", border = "FB464C", bg = "FFEBEE" },
    fail      = { icon = "❌", border = "FB464C", bg = "FFEBEE" },
    missing   = { icon = "❌", border = "FB464C", bg = "FFEBEE" },
    bug       = { icon = "🐛", border = "FB464C", bg = "FFEBEE" },
    example   = { icon = "📖", border = "7C4DFF", bg = "EDE7F6" },
    quote     = { icon = "💬", border = "9E9E9E", bg = "F5F5F5" },
    cite      = { icon = "💬", border = "9E9E9E", bg = "F5F5F5" },
}
local default_def = { icon = "📌", border = "448AFF", bg = "E8F0FE" }

--------------------------------------------------------------------------------
-- XML helpers
--------------------------------------------------------------------------------
local function esc(s)
    return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

-- Wrap text in a <w:r> run with optional run-properties XML string
local function run(text, rpr)
    rpr = rpr or ""
    return '<w:r>' .. rpr
        .. '<w:t xml:space="preserve">' .. esc(text) .. '</w:t></w:r>'
end

--------------------------------------------------------------------------------
-- Inline -> OpenXML conversion
-- Handles: Str, Space, SoftBreak, LineBreak, Strong, Emph, Code,
--          Strikeout, Superscript, Subscript, Link, Span, RawInline, others.
--------------------------------------------------------------------------------
local function inlines_to_xml(inlines, parent_rpr)
    parent_rpr = parent_rpr or ""
    local out = {}

    for _, il in ipairs(inlines) do
        if il.t == "Str" then
            table.insert(out, run(il.text, '<w:rPr>' .. parent_rpr .. '</w:rPr>'))

        elseif il.t == "Space" then
            table.insert(out, run(" ", '<w:rPr>' .. parent_rpr .. '</w:rPr>'))

        elseif il.t == "SoftBreak" then
            table.insert(out, '<w:r><w:br/></w:r>')

        elseif il.t == "LineBreak" then
            table.insert(out, '<w:r><w:br/></w:r>')

        elseif il.t == "Strong" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr .. '<w:b/><w:bCs/>'))

        elseif il.t == "Emph" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr .. '<w:i/><w:iCs/>'))

        elseif il.t == "Strikeout" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr .. '<w:strike/>'))

        elseif il.t == "Superscript" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr .. '<w:vertAlign w:val="superscript"/>'))

        elseif il.t == "Subscript" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr .. '<w:vertAlign w:val="subscript"/>'))

        elseif il.t == "Code" then
            local code_rpr = parent_rpr .. '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>'
                           .. '<w:shd w:val="clear" w:color="auto" w:fill="E0E0E0"/>'
            table.insert(out, run(il.text, '<w:rPr>' .. code_rpr .. '</w:rPr>'))

        elseif il.t == "Link" then
            -- Render link text as underlined blue, then show URL in parentheses
            local link_rpr = parent_rpr .. '<w:color w:val="0563C1"/><w:u w:val="single"/>'
            table.insert(out, inlines_to_xml(il.content, link_rpr))

        elseif il.t == "Span" then
            table.insert(out, inlines_to_xml(il.content, parent_rpr))

        elseif il.t == "RawInline" and il.format == "openxml" then
            table.insert(out, il.text)

        else
            -- Fallback: stringify and render as plain text
            table.insert(out, run(stringify({il}), '<w:rPr>' .. parent_rpr .. '</w:rPr>'))
        end
    end

    return table.concat(out)
end

--------------------------------------------------------------------------------
-- Block -> OpenXML conversion
-- Handles: Para, Plain, CodeBlock, BulletList, OrderedList, Header,
--          HorizontalRule, BlockQuote, Div, RawBlock, others.
--------------------------------------------------------------------------------
local function blocks_to_xml(blocks)
    local out = {}

    for _, bl in ipairs(blocks) do
        if bl.t == "Para" or bl.t == "Plain" then
            table.insert(out, '<w:p>' .. inlines_to_xml(bl.content) .. '</w:p>')

        elseif bl.t == "CodeBlock" then
            -- Render each line as a paragraph with monospace font
            for line in (bl.text .. "\n"):gmatch("(.-)\n") do
                table.insert(out,
                    '<w:p><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="F5F5F5"/></w:pPr>'
                 .. run(line, '<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>'
                            .. '<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>')
                 .. '</w:p>')
            end

        elseif bl.t == "BulletList" then
            for _, item in ipairs(bl.content) do
                -- Each item is a list of blocks; render inline with bullet prefix
                local item_xml = ""
                for _, sub in ipairs(item) do
                    if sub.t == "Para" or sub.t == "Plain" then
                        item_xml = item_xml .. inlines_to_xml(sub.content)
                    else
                        item_xml = item_xml .. run(stringify({sub}))
                    end
                end
                table.insert(out,
                    '<w:p>'
                 .. run("•  ")
                 .. item_xml
                 .. '</w:p>')
            end

        elseif bl.t == "OrderedList" then
            local num = bl.listAttributes and bl.listAttributes.start or 1
            for _, item in ipairs(bl.content) do
                local item_xml = ""
                for _, sub in ipairs(item) do
                    if sub.t == "Para" or sub.t == "Plain" then
                        item_xml = item_xml .. inlines_to_xml(sub.content)
                    else
                        item_xml = item_xml .. run(stringify({sub}))
                    end
                end
                table.insert(out,
                    '<w:p>'
                 .. run(tostring(num) .. ". ")
                 .. item_xml
                 .. '</w:p>')
                num = num + 1
            end

        elseif bl.t == "Header" then
            local level = bl.level or 2
            local style = "Heading" .. tostring(level)
            table.insert(out,
                '<w:p><w:pPr><w:pStyle w:val="' .. style .. '"/></w:pPr>'
             .. inlines_to_xml(bl.content, '<w:b/><w:bCs/>')
             .. '</w:p>')

        elseif bl.t == "HorizontalRule" then
            table.insert(out,
                '<w:p><w:pPr><w:pBdr>'
             .. '<w:bottom w:val="single" w:sz="6" w:space="1" w:color="AAAAAA"/>'
             .. '</w:pBdr></w:pPr></w:p>')

        elseif bl.t == "BlockQuote" then
            -- Nested blockquote: indent and render children
            for _, sub in ipairs(bl.content) do
                if sub.t == "Para" or sub.t == "Plain" then
                    table.insert(out,
                        '<w:p><w:pPr><w:ind w:left="400"/></w:pPr>'
                     .. inlines_to_xml(sub.content)
                     .. '</w:p>')
                else
                    table.insert(out, blocks_to_xml({sub}))
                end
            end

        elseif bl.t == "Div" then
            table.insert(out, blocks_to_xml(bl.content))

        elseif bl.t == "RawBlock" and bl.format == "openxml" then
            table.insert(out, bl.text)

        else
            -- Fallback
            table.insert(out,
                '<w:p>' .. run(stringify({bl})) .. '</w:p>')
        end
    end

    return table.concat(out)
end

--------------------------------------------------------------------------------
-- Main filter
--------------------------------------------------------------------------------
function BlockQuote(el)
    if FORMAT ~= "docx" then return el end

    local start = el.content[1]
    if start == nil or start.t ~= "Para" then return el end

    local first = start.content[1]
    if first == nil or first.t ~= "Str" then return el end

    -- Match Obsidian callout: [!type], [!type]+, [!type]-
    local callout_type = first.text:match("^%[!([%w%-]+)%][-+]?$")
    if not callout_type then return el end

    local def = callout_defs[callout_type:lower()] or default_def

    ---------- Split first Para into title vs body ----------
    local title_inlines = pandoc.List()
    local body_inlines  = pandoc.List()
    local found_break   = false

    for i = 2, #start.content do
        local node = start.content[i]
        if not found_break then
            if node.t == "SoftBreak" or node.t == "LineBreak" then
                found_break = true
            else
                title_inlines:insert(node)
            end
        else
            body_inlines:insert(node)
        end
    end

    if #title_inlines > 0 and title_inlines[1].t == "Space" then
        title_inlines:remove(1)
    end

    local title_text
    if #title_inlines > 0 then
        title_text = stringify(title_inlines)
    else
        title_text = callout_type:sub(1,1):upper() .. callout_type:sub(2):lower()
    end

    ---------- Build content blocks ----------
    local content_blocks = pandoc.List()
    if #body_inlines > 0 then
        content_blocks:insert(pandoc.Para(body_inlines))
    end
    for i = 2, #el.content do
        content_blocks:insert(el.content[i])
    end

    ---------- Produce OpenXML ----------
    local content_xml = blocks_to_xml(content_blocks)

    -- Title paragraph: icon + bold coloured text
    local title_xml = string.format(
        '<w:p>'
     .. '<w:pPr><w:spacing w:after="80"/></w:pPr>'
     .. '<w:r><w:rPr>'
     .. '<w:b/><w:bCs/><w:color w:val="%s"/><w:sz w:val="22"/><w:szCs w:val="22"/>'
     .. '</w:rPr>'
     .. '<w:t xml:space="preserve">%s %s</w:t></w:r>'
     .. '</w:p>',
        def.border, def.icon, esc(title_text))

    -- Single-cell table: thick coloured left border + light background
    local xml = string.format(
        '<w:tbl>'
     .. '<w:tblPr>'
     ..   '<w:tblW w:w="5000" w:type="pct"/>'
     ..   '<w:jc w:val="left"/>'
     ..   '<w:tblBorders>'
     ..     '<w:top    w:val="single" w:sz="4"  w:space="0" w:color="%s"/>'
     ..     '<w:left   w:val="single" w:sz="24" w:space="0" w:color="%s"/>'
     ..     '<w:bottom w:val="single" w:sz="4"  w:space="0" w:color="%s"/>'
     ..     '<w:right  w:val="single" w:sz="4"  w:space="0" w:color="%s"/>'
     ..   '</w:tblBorders>'
     ..   '<w:tblCellMar>'
     ..     '<w:top    w:w="100" w:type="dxa"/>'
     ..     '<w:left   w:w="180" w:type="dxa"/>'
     ..     '<w:bottom w:w="100" w:type="dxa"/>'
     ..     '<w:right  w:w="180" w:type="dxa"/>'
     ..   '</w:tblCellMar>'
     .. '</w:tblPr>'
     .. '<w:tr><w:tc>'
     ..   '<w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="%s"/></w:tcPr>'
     ..   '%s'
     ..   '%s'
     .. '</w:tc></w:tr>'
     .. '</w:tbl>',
        def.border, def.border, def.border, def.border,
        def.bg,
        title_xml,
        content_xml)

    return pandoc.RawBlock("openxml", xml)
end