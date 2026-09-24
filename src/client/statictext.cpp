/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "statictext.h"

#include "gameconfig.h"
#include "map.h"
#include "framework/core/clock.h"
#include "framework/core/eventdispatcher.h"
#include "framework/core/graphicalapplication.h"
#include "framework/graphics/fontmanager.h"

namespace {
const Color* getLocationLabelPalette(const std::string_view text)
{
    static const Color trainers[] = { Color(73, 187, 255), Color(91, 146, 255), Color(66, 220, 237), Color(128, 174, 255) };
    static const Color bosses[] = { Color(255, 84, 101), Color(255, 121, 83), Color(230, 86, 163), Color(255, 160, 92) };
    static const Color hunts[] = { Color(80, 222, 122), Color(48, 205, 173), Color(148, 225, 79), Color(91, 232, 175) };
    static const Color quests[] = { Color(255, 213, 77), Color(255, 175, 76), Color(240, 226, 105), Color(255, 198, 114) };
    static const Color bossIsland[] = { Color(178, 116, 255), Color(222, 132, 243), Color(143, 143, 255), Color(198, 158, 255) };

    if (text == "TRAINERS") return trainers;
    if (text == "BOSSES") return bosses;
    if (text == "HUNTS") return hunts;
    if (text == "QUESTS") return quests;
    if (text == "BOSS ISLAND") return bossIsland;
    return nullptr;
}
} // namespace

StaticText::StaticText()
{
    m_cachedText.setFont(g_gameConfig.getStaticTextFont());
    m_cachedText.setAlign(Fw::AlignCenter);
}

void StaticText::drawText(const Point& dest, const Rect& parentRect)
{
    const auto& textSize = m_cachedText.getTextSize();

    auto rect = Rect(dest - Point(textSize.width() / 2, textSize.height()) + (Point(20, 5) / g_app.getStaticTextScale()), textSize);
    if (g_app.getStaticTextScale() == DEFAULT_DISPLAY_DENSITY)
        rect.bind(parentRect);

    // draw only if the real center is not too far from the parent center, or its a yell
    //if(g_map.isAwareOfPosition(m_position) || isYell()) {
    m_cachedText.draw(rect, m_color);
    //}
}

void StaticText::setText(const std::string_view text)
{
    m_cachedText.setTextColors({});
    m_cachedText.setText(text);
}
void StaticText::setFont(const std::string_view fontName) { m_cachedText.setFont(g_fonts.getFont(fontName)); }

bool StaticText::addMessage(const std::string_view name, const Otc::MessageMode mode, const std::string_view text)
{
    const bool isLocationLabel = (mode == Otc::MessageMonsterSay || mode == Otc::MessageBarkLow) && getLocationLabelPalette(text);
    if (m_messages.empty()) {
        m_name = name;
        m_mode = mode;
        m_isLocationLabel = isLocationLabel;
    } else if (m_name != name || m_mode != mode || m_isLocationLabel != isLocationLabel
               || (isLocationLabel && m_messages.front().first != text)) {
        return false;
    } else if (!isLocationLabel && m_messages.size() > 10) {
        m_messages.pop_front();
        m_updateEvent->cancel();
        m_updateEvent = nullptr;
    }

    if (isLocationLabel && m_messages.size() >= 3) {
        m_messages.pop_front();
        m_locationLabelColors.pop_front();
        if (m_updateEvent) {
            m_updateEvent->cancel();
            m_updateEvent = nullptr;
        }
    }

    int delay = std::max<int>(g_gameConfig.getStaticDurationPerCharacter() * text.length(), g_gameConfig.getMinStatictextDuration());
    if (isLocationLabel)
        delay = 2400;
    else if (isYell())
        delay *= 2;

    if (g_app.mustOptimize())
        delay /= 2;

    m_messages.emplace_back(text, g_clock.millis() + delay);
    if (isLocationLabel) {
        // The next pulse always picks a different shade from this label's palette.
        const int step = 1 + static_cast<int>(g_clock.millis() % 3);
        m_lastLocationLabelColor = (m_lastLocationLabelColor + step) % 4;
        m_locationLabelColors.push_back(static_cast<uint8_t>(m_lastLocationLabelColor));
    }
    compose();

    if (!m_updateEvent)
        scheduleUpdate();

    return true;
}

void StaticText::update()
{
    m_messages.pop_front();
    if (m_isLocationLabel)
        m_locationLabelColors.pop_front();
    if (m_messages.empty()) {
        // schedule removal
        g_textDispatcher.addEvent([self = asStaticText()] { g_map.removeStaticText(self); });
    } else {
        compose();
        scheduleUpdate();
    }
}

void StaticText::scheduleUpdate()
{
    const int delay = std::max<int>(m_messages.front().second - g_clock.millis(), 0);
    m_updateEvent = g_dispatcher.scheduleEvent([self = asStaticText()] {
        self->m_updateEvent = nullptr;
        self->update();
    }, delay);
}

void StaticText::compose()
{
    static constexpr Color
        MESSAGE_COLOR1(239, 239, 0),
        MESSAGE_COLOR2(254, 101, 0),
        MESSAGE_COLOR3(95, 247, 247),
        NPC_KEYWORD_COLOR(31, 159, 254);

    //TODO: this could be moved to lua
    std::string text;

    if (m_mode == Otc::MessageSay) {
        text += m_name;
        text += " says:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageWhisper) {
        text += m_name;
        text += " whispers:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageYell) {
        text += m_name;
        text += " yells:\n";
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageSpell) {
        // Baiakeros uses the traditional spell incantation presentation:
        // yellow text over the creature, without the emote/monster color.
        m_color = MESSAGE_COLOR1;
    } else if (m_mode == Otc::MessageMonsterSay || m_mode == Otc::MessageMonsterYell
               || m_mode == Otc::MessageBarkLow || m_mode == Otc::MessageBarkLoud) {
        m_color = MESSAGE_COLOR2;
    } else if (m_mode == Otc::MessageNpcFrom || m_mode == Otc::MessageNpcFromStartBlock) {
        text += m_name;
        text += " says:\n";
        m_color = MESSAGE_COLOR3;
    } else {
        g_logger.warning("Unknown speak type: {}", static_cast<uint8_t>(m_mode));
    }

    if (m_isLocationLabel) {
        const Color* palette = getLocationLabelPalette(m_messages.front().first);
        std::vector<std::pair<int, Color>> textColors;
        for (uint32_t i = 0; i < m_messages.size(); ++i) {
            textColors.emplace_back(static_cast<int>(text.size()), palette[m_locationLabelColors[i]]);
            text += m_messages[i].first;
            if (i + 1 < m_messages.size())
                text += "\n";
        }
        m_cachedText.setText(text);
        m_cachedText.setTextColors(std::move(textColors));
        m_cachedText.wrapText(275);
        return;
    }

    for (uint32_t i = 0; i < m_messages.size(); ++i) {
        text += m_messages[i].first;

        if (i < m_messages.size() - 1)
            text += "\n";
    }

    std::vector<std::pair<int, Color>> textColors;
    if (m_mode == Otc::MessageNpcFrom || m_mode == Otc::MessageNpcFromStartBlock) {
        std::string parsedText;
        parsedText.reserve(text.size());
        textColors.emplace_back(0, MESSAGE_COLOR3);

        const auto setTextColor = [&textColors](const int position, const Color& color) {
            if (!textColors.empty() && textColors.back().first == position)
                textColors.back().second = color;
            else
                textColors.emplace_back(position, color);
        };

        for (size_t i = 0; i < text.size();) {
            if (text[i] != '{') {
                parsedText += text[i++];
                continue;
            }

            const size_t closingBrace = text.find('}', i + 1);
            if (closingBrace == std::string::npos) {
                parsedText += text[i++];
                continue;
            }

            std::string_view keyword(text.data() + i + 1, closingBrace - i - 1);
            if (const size_t comma = keyword.find(','); comma != std::string_view::npos)
                keyword = keyword.substr(0, comma);

            setTextColor(static_cast<int>(parsedText.size()), NPC_KEYWORD_COLOR);
            parsedText.append(keyword);
            setTextColor(static_cast<int>(parsedText.size()), MESSAGE_COLOR3);
            i = closingBrace + 1;
        }

        text = std::move(parsedText);
    }

    m_cachedText.setText(text);
    m_cachedText.setTextColors(std::move(textColors));
    m_cachedText.wrapText(275);
}
