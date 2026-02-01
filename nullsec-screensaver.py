#!/usr/bin/env python3
"""
NullSec Linux - Custom Animated Screensaver
AI-Generated Matrix-Style Visual with NullSec Branding
"""

import sys
import random
import time
from PyQt5.QtWidgets import QApplication, QWidget
from PyQt5.QtCore import QTimer, Qt, QPoint
from PyQt5.QtGui import QPainter, QColor, QFont, QPen

class NullSecScreensaver(QWidget):
    def __init__(self):
        super().__init__()
        self.initUI()
        
        # Matrix rain configuration
        self.columns = 100
        self.drops = []
        self.chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%^&*()_+-=[]{}|;:,.<>?/~`"
        self.hex_chars = "0123456789ABCDEF"
        
        # NullSec ASCII art
        self.nullsec_logo = [
            " ███▄    █  █    ██  ██▓     ██▓      ██████ ▓█████  ▄████▄",
            " ██ ▀█   █  ██  ▓██▒▓██▒    ▓██▒    ▒██    ▒ ▓█   ▀ ▒██▀ ▀█",
            "▓██  ▀█ ██▒▓██  ▒██░▒██░    ▒██░    ░ ▓██▄   ▒███   ▒▓█    ▄",
            "▓██▒  ▐▌██▒▓▓█  ░██░▒██░    ▒██░      ▒   ██▒▒▓█  ▄ ▒▓▓▄ ▄██▒",
            "▒██░   ▓██░▒▒█████▓ ░██████▒░██████▒▒██████▒▒░▒████▒▒ ▓███▀ ░",
            "░ ▒░   ▒ ▒ ░▒▓▒ ▒ ▒ ░ ▒░▓  ░░ ▒░▓  ░▒ ▒▓▒ ▒ ░░░ ▒░ ░░ ░▒ ▒  ░",
            "░ ░░   ░ ▒░░░▒░ ░ ░ ░ ░ ▒  ░░ ░ ▒  ░░ ░▒  ░ ░ ░ ░  ░  ░  ▒",
            "   ░   ░ ░  ░░░ ░ ░   ░ ░     ░ ░   ░  ░  ░     ░   ░",
            "         ░    ░         ░  ░    ░  ░      ░     ░  ░░ ░",
            "                                                    ░"
        ]
        
        # Hacking messages
        self.messages = [
            "SYSTEM IDLE - MONITORING...",
            "NULLSEC LINUX 1.0 (VOID)",
            "185 ATTACK MODULES LOADED",
            "12 AI MODELS ACTIVE",
            "SECURITY PROTOCOLS ENGAGED",
            "OFFENSIVE MODE: STANDBY",
            "FRAMEWORK v2.0 READY",
            "PENETRATION TESTING OS",
            "VOID CODENAME ACTIVE",
            "NULLSEC AI ONLINE",
            "NO THREATS DETECTED",
            "ALL SYSTEMS OPERATIONAL"
        ]
        
        # Animation state
        self.logo_alpha = 0
        self.logo_fade_in = True
        self.message_index = 0
        self.scan_line_y = 0
        self.hex_stream = []
        self.binary_particles = []
        
        # Initialize drops
        self.reset_drops()
        
        # Timer for animation
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_animation)
        self.timer.start(50)  # 20 FPS
        
    def initUI(self):
        self.setWindowTitle('NullSec Linux Screensaver')
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)
        self.setAttribute(Qt.WA_TranslucentBackground, False)
        self.setStyleSheet("background-color: black;")
        self.showFullScreen()
        self.setCursor(Qt.BlankCursor)
        
    def reset_drops(self):
        """Initialize matrix rain drops"""
        self.drops = []
        for i in range(self.columns):
            self.drops.append({
                'x': i * 12,
                'y': random.randint(-500, 0),
                'speed': random.randint(5, 15),
                'length': random.randint(10, 30),
                'chars': [random.choice(self.chars) for _ in range(30)]
            })
    
    def update_animation(self):
        """Update all animation elements"""
        # Update matrix drops
        for drop in self.drops:
            drop['y'] += drop['speed']
            if drop['y'] > self.height() + 100:
                drop['y'] = random.randint(-200, -50)
                drop['chars'] = [random.choice(self.chars) for _ in range(30)]
        
        # Update logo fade
        if self.logo_fade_in:
            self.logo_alpha = min(255, self.logo_alpha + 3)
            if self.logo_alpha >= 255:
                self.logo_fade_in = False
        else:
            self.logo_alpha = max(180, self.logo_alpha - 1)
            if self.logo_alpha <= 180:
                self.logo_fade_in = True
        
        # Update scan line
        self.scan_line_y = (self.scan_line_y + 3) % self.height()
        
        # Update hex stream
        if random.random() < 0.3:
            self.hex_stream.append({
                'x': random.randint(0, self.width()),
                'y': 0,
                'text': ''.join([random.choice(self.hex_chars) for _ in range(8)]),
                'speed': random.randint(2, 8)
            })
        
        self.hex_stream = [h for h in self.hex_stream if h['y'] < self.height()]
        for h in self.hex_stream:
            h['y'] += h['speed']
        
        # Rotate message every 5 seconds
        if random.random() < 0.01:
            self.message_index = (self.message_index + 1) % len(self.messages)
        
        # Binary particles
        if random.random() < 0.2:
            self.binary_particles.append({
                'x': random.randint(0, self.width()),
                'y': self.height(),
                'text': random.choice(['0', '1']),
                'vy': random.randint(-3, -1),
                'life': 100
            })
        
        self.binary_particles = [p for p in self.binary_particles if p['life'] > 0]
        for p in self.binary_particles:
            p['y'] += p['vy']
            p['life'] -= 2
        
        self.update()
    
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        # Black background
        painter.fillRect(self.rect(), QColor(0, 0, 0))
        
        # Draw matrix rain
        self.draw_matrix_rain(painter)
        
        # Draw hex stream
        self.draw_hex_stream(painter)
        
        # Draw binary particles
        self.draw_binary_particles(painter)
        
        # Draw scan line
        self.draw_scan_line(painter)
        
        # Draw NullSec logo (center)
        self.draw_logo(painter)
        
        # Draw status message
        self.draw_status_message(painter)
        
        # Draw corner info
        self.draw_corner_info(painter)
    
    def draw_matrix_rain(self, painter):
        """Draw falling matrix-style characters"""
        font = QFont("Courier New", 12)
        painter.setFont(font)
        
        for drop in self.drops:
            for i, char in enumerate(drop['chars'][:drop['length']]):
                y = drop['y'] - (i * 15)
                if 0 <= y <= self.height():
                    # Fade effect
                    alpha = int(255 * (1 - i / drop['length']))
                    if i == 0:
                        # Brightest at the head
                        color = QColor(0, 255, 70, alpha)
                    else:
                        color = QColor(0, 180, 50, alpha)
                    
                    painter.setPen(color)
                    painter.drawText(QPoint(drop['x'], y), char)
    
    def draw_hex_stream(self, painter):
        """Draw hexadecimal data streams"""
        font = QFont("Courier New", 10)
        painter.setFont(font)
        
        for h in self.hex_stream:
            alpha = min(255, int(255 * (1 - h['y'] / self.height())))
            painter.setPen(QColor(0, 255, 255, alpha))
            painter.drawText(QPoint(h['x'], h['y']), h['text'])
    
    def draw_binary_particles(self, painter):
        """Draw floating binary digits"""
        font = QFont("Courier New", 14, QFont.Bold)
        painter.setFont(font)
        
        for p in self.binary_particles:
            alpha = int(255 * (p['life'] / 100))
            painter.setPen(QColor(255, 0, 100, alpha))
            painter.drawText(QPoint(p['x'], p['y']), p['text'])
    
    def draw_scan_line(self, painter):
        """Draw scanning line effect"""
        painter.setPen(QPen(QColor(0, 255, 255, 30), 2))
        painter.drawLine(0, self.scan_line_y, self.width(), self.scan_line_y)
    
    def draw_logo(self, painter):
        """Draw NullSec ASCII logo in center"""
        font = QFont("Courier New", 14, QFont.Bold)
        painter.setFont(font)
        
        center_x = self.width() // 2
        center_y = self.height() // 2 - 100
        
        for i, line in enumerate(self.nullsec_logo):
            y = center_y + (i * 20)
            x = center_x - (len(line) * 4)
            
            # Glowing effect with multiple layers
            for offset in range(3, 0, -1):
                alpha = int(self.logo_alpha * (0.3 - offset * 0.1))
                painter.setPen(QColor(0, 255, 100, alpha))
                painter.drawText(QPoint(x, y), line)
            
            # Main text
            painter.setPen(QColor(0, 255, 100, self.logo_alpha))
            painter.drawText(QPoint(x, y), line)
    
    def draw_status_message(self, painter):
        """Draw status message below logo"""
        font = QFont("Courier New", 16, QFont.Bold)
        painter.setFont(font)
        
        message = self.messages[self.message_index]
        
        # Calculate position
        metrics = painter.fontMetrics()
        text_width = metrics.horizontalAdvance(message)
        x = (self.width() - text_width) // 2
        y = self.height() // 2 + 150
        
        # Glowing border
        for offset in [(1,1), (-1,-1), (1,-1), (-1,1)]:
            painter.setPen(QColor(0, 255, 255, 100))
            painter.drawText(QPoint(x + offset[0], y + offset[1]), message)
        
        # Main text
        painter.setPen(QColor(0, 255, 255, 255))
        painter.drawText(QPoint(x, y), message)
    
    def draw_corner_info(self, painter):
        """Draw system info in corners"""
        font = QFont("Courier New", 10)
        painter.setFont(font)
        painter.setPen(QColor(0, 255, 100, 200))
        
        # Top left
        painter.drawText(QPoint(20, 30), "NULLSEC LINUX 1.0")
        painter.drawText(QPoint(20, 50), "CODENAME: VOID")
        
        # Top right
        time_str = time.strftime("%H:%M:%S")
        date_str = time.strftime("%Y-%m-%d")
        painter.drawText(QPoint(self.width() - 120, 30), time_str)
        painter.drawText(QPoint(self.width() - 120, 50), date_str)
        
        # Bottom left
        painter.drawText(QPoint(20, self.height() - 50), "FRAMEWORK v2.0")
        painter.drawText(QPoint(20, self.height() - 30), "185 MODULES")
        
        # Bottom right
        painter.drawText(QPoint(self.width() - 150, self.height() - 50), "PRESS ANY KEY")
        painter.drawText(QPoint(self.width() - 150, self.height() - 30), "TO EXIT")
    
    def keyPressEvent(self, event):
        """Exit on any key press"""
        self.close()
    
    def mousePressEvent(self, event):
        """Exit on mouse click"""
        self.close()
    
    def mouseMoveEvent(self, event):
        """Exit on mouse movement"""
        self.close()


def main():
    app = QApplication(sys.argv)
    screensaver = NullSecScreensaver()
    screensaver.show()
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()
