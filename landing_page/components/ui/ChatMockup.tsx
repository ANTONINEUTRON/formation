"use client";

import { useEffect, useState } from "react";

const chatMessages = [
  {
    type: "user" as const,
    text: "Buy SOL when it drops 5% in an hour",
    delay: 0,
  },
  {
    type: "agent" as const,
    text: "Got it! A few questions:",
    delay: 1200,
  },
  {
    type: "agent" as const,
    text: "How much per trade?",
    delay: 2000,
  },
  {
    type: "user" as const,
    text: "$500, max 2 trades per day",
    delay: 3500,
  },
  {
    type: "agent" as const,
    text: "Strategy activated ✓",
    delay: 4800,
    highlight: true,
  },
];

export function ChatMockup() {
  const [visibleMessages, setVisibleMessages] = useState<number>(0);

  useEffect(() => {
    const timers: NodeJS.Timeout[] = [];

    chatMessages.forEach((msg, index) => {
      const timer = setTimeout(() => {
        setVisibleMessages(index + 1);
      }, msg.delay);
      timers.push(timer);
    });

    // Loop animation
    const resetTimer = setTimeout(() => {
      setVisibleMessages(0);
      // Restart after a brief pause
      setTimeout(() => {
        setVisibleMessages(1);
      }, 500);
    }, 7000);
    timers.push(resetTimer);

    return () => timers.forEach(clearTimeout);
  }, [visibleMessages === 0]);

  return (
    <div className="flex items-center justify-center w-full h-full p-4 md:p-8">
      {/* Mobile device frame */}
      <div className="relative w-[280px] md:w-[320px] h-[560px] md:h-[640px] bg-zinc-900 rounded-[40px] p-2 shadow-2xl">
        {/* Phone notch */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-32 h-6 bg-zinc-900 rounded-b-2xl z-20" />
        <div className="absolute top-2 left-1/2 -translate-x-1/2 w-20 h-5 bg-black rounded-full z-20" />
        
        {/* Screen */}
        <div className="relative w-full h-full bg-bg rounded-[32px] overflow-hidden border border-border">
          {/* Status bar */}
          <div className="flex items-center justify-between px-6 py-2 text-xs text-text-muted">
            <span>9:41</span>
            <div className="flex items-center gap-1">
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9-4.03-9-9-9zm0 16c-3.86 0-7-3.14-7-7s3.14-7 7-7 7 3.14 7 7-3.14 7-7 7z" />
              </svg>
              <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path d="M17 4h-3V2h-4v2H7v18h10V4z" />
              </svg>
            </div>
          </div>

          {/* App content */}
          <div className="flex flex-col h-[calc(100%-32px)] p-3">
            {/* Header */}
            <div className="flex items-center gap-2 pb-3 border-b border-border">
              <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center">
                <span className="text-sm">🤖</span>
              </div>
              <div className="flex-1">
                <p className="font-semibold text-text text-xs">TraderBot</p>
                <p className="text-[10px] text-text-muted">Active • Semi-auto</p>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-1.5 h-1.5 rounded-full bg-success animate-pulse" />
                <span className="text-[10px] text-success">Online</span>
              </div>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-hidden py-3 space-y-2">
              {chatMessages.slice(0, visibleMessages).map((msg, index) => (
                <div
                  key={index}
                  className={`flex ${msg.type === "user" ? "justify-end" : "justify-start"} animate-fadeIn`}
                >
                  <div
                    className={`max-w-[85%] px-2.5 py-1.5 rounded-lg text-xs ${
                      msg.type === "user"
                        ? "bg-primary text-white"
                        : msg.highlight
                          ? "bg-success/20 text-success border border-success/30"
                          : "bg-surface-light text-text border border-border"
                    }`}
                  >
                    {msg.text}
                  </div>
                </div>
              ))}

              {/* Typing indicator */}
              {visibleMessages > 0 && visibleMessages < chatMessages.length && (
                <div className="flex justify-start">
                  <div className="bg-surface-light border border-border px-2.5 py-1.5 rounded-lg">
                    <div className="flex gap-1">
                      <div className="w-1.5 h-1.5 bg-text-muted rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
                      <div className="w-1.5 h-1.5 bg-text-muted rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
                      <div className="w-1.5 h-1.5 bg-text-muted rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Input area */}
            <div className="pt-2 border-t border-border">
              <div className="flex items-center gap-2">
                <div className="flex-1 bg-surface-light border border-border rounded-full px-3 py-1.5">
                  <span className="text-text-muted text-[10px]">Type strategy...</span>
                </div>
                <button className="w-7 h-7 bg-primary rounded-full flex items-center justify-center text-white">
                  <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Home indicator */}
        <div className="absolute bottom-1 left-1/2 -translate-x-1/2 w-28 h-1 bg-zinc-600 rounded-full" />
      </div>
    </div>
  );
}
