-- TI-Nspire Lua Interactive Notes: Circuit Analysis Toolkit 
-- Author: John Putnam & ChatGPT
-- Date: 2025-04-22

-- How to use:
-- 1. On your TI-Nspire CX II CAS, open a new document and insert a Lua script application.
-- 2. Paste this entire code into the script editor.
-- 3. Press Ctrl-R (PC) or Menu▶Check Script▶Run (handheld) to execute.
-- 4. Use the menu to browse notes.

-- Lightweight menu framework
local Screens = {}

function push_screen(screen, ...)
    if #Screens > 0 and Screens[#Screens].loseFocus then
        Screens[#Screens]:loseFocus()
    end
    table.insert(Screens, screen)
    if screen.pushed then screen:pushed(...) end
    if screen.giveFocus then screen:giveFocus() end
    platform.window:invalidate()
end

function pop_screen()
    if #Screens == 0 then return end
    local old = table.remove(Screens)
    if old.loseFocus then old:loseFocus() end
    local top = Screens[#Screens]
    if top and top.giveFocus then top:giveFocus() end
    platform.window:invalidate()
end

-- Core screen/widget classes
WScreen = function()
    local self = { widgets = {}, focus = 0 }
    function self:appendWidget(w, x, y)
        w.x, w.y, w.parent = x or 0, y or 0, self
        table.insert(self.widgets, w)
    end
    function self:draw(gc)
        if self.paint then self:paint(gc) end
        for _,w in ipairs(self.widgets) do if w.paint then w:paint(gc) end end
    end
    function self:giveFocus()
        if self.widgets[1] and self.widgets[1].giveFocus then
            self.widgets[1]:giveFocus()
        end
    end
    function self:loseFocus()
        for _,w in ipairs(self.widgets) do if w.loseFocus then w:loseFocus() end end
    end
    function self:mouseDown(x,y) for _,w in ipairs(self.widgets) do if w.mouseDown then w:mouseDown(x,y) end end end
    function self:mouseMove(x,y) for _,w in ipairs(self.widgets) do if w.mouseMove then w:mouseMove(x,y) end end end
    function self:mouseUp(x,y)   for _,w in ipairs(self.widgets) do if w.mouseUp   then w:mouseUp(x,y)   end end end
    return self
end

sList = function()
    local self = { items={}, sel=1, hasFocus=false, x=0, y=0, w=200, h=200, ih=18, top=0,
                   font={"sansserif","r",10}, colors={40,148,184} }
    function self:setSize(w,h)
        if w then self.w = (w<0) and math.max(1, platform.window:width()+w-self.x) or w end
        if h then self.h = (h<0) and math.max(self.ih, platform.window:height()+h-self.y) or h end
    end
    function self:giveFocus() self.hasFocus=true; platform.window:invalidate() end
    function self:loseFocus() self.hasFocus=false; platform.window:invalidate() end
    function self:reset() self.sel=1; self.top=0 end
    function self:paint(gc)
        local x,y,w,h,ih,top,sel,items = self.x,self.y,self.w,self.h,self.ih,self.top,self.sel,self.items
        if w<1 then w=1 end; if h<1 then h=1 end; local visible = math.floor(h/ih)
        gc:setColorRGB(255,255,255); gc:fillRect(x,y,w,h)
        gc:setColorRGB(0,0,0); gc:drawRect(x,y,w,h)
        gc:setFont(unpack(self.font))
        for i=1,math.min(#items-top,visible) do
            if i+top==sel then
                gc:setColorRGB(unpack(self.colors)); gc:fillRect(x+1,y+(i-1)*ih+1,w-2,ih)
                gc:setColorRGB(255,255,255)
                if self.hasFocus then gc:setColorRGB(255,255,0); gc:fillPolygon({x+2,y+(i-1)*ih+7,x+8,y+(i-1)*ih+3,x+8,y+(i-1)*ih+13}) end
            end
            gc:setColorRGB(0,0,0); gc:drawString(items[i+top], x+15, y+(i-1)*ih, "top")
        end
        -- Draw scrollbar if content is larger than visible
        if #items > visible then
            local scrollBarWidth = 6
            local barX = x + w - scrollBarWidth - 1
            local barY = y + 1
            local barHeight = h - 2
            gc:setColorRGB(220,220,220) -- scrollbar track
            gc:fillRect(barX, barY, scrollBarWidth, barHeight)
            local thumbHeight = math.max(math.floor(barHeight * visible / #items), 10)
            local maxTop = #items - visible
            local thumbY = (maxTop > 0) and (y + 1 + (top / maxTop) * (barHeight - thumbHeight)) or (y + 1)
            gc:setColorRGB(100,100,100) -- scrollbar thumb
            gc:fillRect(barX, thumbY, scrollBarWidth, thumbHeight)
        end
        -- Fix: draw focus rectangle to match list height, not content height
        if self.hasFocus then gc:setColorRGB(40,148,184); gc:drawRect(x,y,w,h) end
    end
    function self:enterKey() if self.action then self:action(self.sel) end end
    function self:escapeKey() if self.parent and self.parent.escapeKey then self.parent:escapeKey() end end
    function self:mouseMove(x,y) local idx=math.floor((y-self.y)/self.ih)+1+self.top if idx>=1 and idx<=#self.items then self.sel=idx; platform.window:invalidate() end end
    function self:mouseDown(x,y) self:giveFocus(); self:mouseMove(x,y) end
    function self:mouseUp(x,y) local idx=math.floor((y-self.y)/self.ih)+1+self.top if idx>=1 and idx<=#self.items and self.action then self.action(self,idx) end end
    -- New: handle arrow key navigation
    function self:arrowKey(arrow)
        local visibleItems = math.floor(self.h / self.ih)
        if arrow == "up" then
            if self.sel > 1 then
                self.sel = self.sel - 1
                if self.sel < self.top + 1 then self.top = self.top - 1 end
            end
        elseif arrow == "down" then
            if self.sel < #self.items then
                self.sel = self.sel + 1
                if self.sel > self.top + visibleItems then self.top = self.top + 1 end
            end
        end
        platform.window:invalidate()
    end
    return self
end

-- Events
function on.paint(gc) local top=Screens[#Screens] if top then top:draw(gc) end end
function on.enterKey() local w=getFocusedWidget() if w and w.enterKey then w:enterKey() end end
function on.escapeKey() pop_screen() end
function on.mouseDown(x,y) local top=Screens[#Screens] if top and top.mouseDown then top:mouseDown(x,y) end end
function on.mouseMove(x,y) local top=Screens[#Screens] if top and top.mouseMove then top:mouseMove(x,y) end end
function on.mouseUp(x,y)   local top=Screens[#Screens] if top and top.mouseUp   then top:mouseUp(x,y)   end end
function on.resize() NotesList:setSize(-10,-40); NotesSubList:setSize(-10,-40); platform.window:invalidate() end

-- Data model
NotesCategories = {
  {
    name = "Circuit Analysis Techniques",
    sub = {
      {
        name = "Ohm's Law",
        body = {
          "I = V/R. Ohm's Law states that the current (I) flowing through a conductor is directly proportional to the voltage (V) applied across it and inversely proportional to its resistance (R). This fundamental relationship allows you to calculate any one of the three quantities when the other two are known, under steady-state conditions."
        }
      },
      {
        name = "Kirchhoff's Voltage Law (KVL)",
        body = {
          "The algebraic sum of all voltages around any closed loop must equal zero. Based on energy conservation, each rise and drop in potential cancels out, so ∑V_rises + ∑V_drops = 0. KVL lets you write loop equations to solve for unknown voltages or currents."
        }
      },
      {
        name = "Kirchhoff's Current Law (KCL)",
        body = {
          "The sum of currents entering a node equals the sum leaving that node: ∑I_in = ∑I_out. KCL is founded on charge conservation and underpins nodal analysis by giving you node-voltage equations to find currents and voltages in complex networks."
        }
      },
      {
        name = "Nodal and Mesh Analysis",
        body = {
          "Nodal analysis uses KCL at circuit nodes to form equations in node voltages. Mesh analysis applies KVL around independent loops to form equations in loop currents. Together, they provide systematic methods for analyzing large planar circuits."
        }
      },
      {
        name = "Source Transformation",
        body = {
          "Converts between Thevenin (voltage source + series R) and Norton (current source + parallel R) equivalents. Source transformations simplify circuits by replacing one form with the other, preserving terminal behavior to ease analysis."
        }
      },
      {
        name = "Thevenin's and Norton's Theorems",
        body = {
          "Thevenin’s theorem reduces any linear circuit to a single voltage source and series resistor as seen from two terminals. Norton’s theorem does the same with a current source and parallel resistor. Both simplify load analysis and facilitate maximum power transfer calculations."
        }
      },
      {
        name = "Superposition Theorem",
        body = {
          "In a linear circuit with multiple independent sources, the voltage or current at any element equals the algebraic sum of the contributions from each source acting alone (all other sources turned off). Superposition simplifies multi-source analysis but requires re-combining partial results."
        }
      }
    }
  },

  {
    name = "First and Second Order Transient Circuits",
    sub = {
      {
        name = "First-Order Response",
        body = {
          "First-order circuits contain one energy storage element (R-C or R-L). The time constant τ = RC (for R-C) or τ = L/R (for R-L) defines how quickly the response reaches ~63% of its final value. The transient follows an exponential form, e.g., v(t) = V_final + (V_initial - V_final)e^(-t/τ)."
        }
      },
      {
        name = "Second-Order Response",
        body = {
          "Second-order circuits contain two storage elements (e.g., RLC). Their response depends on damping ratio ζ: overdamped (ζ>1) yields two real exponentials, critically damped (ζ=1) one repeated root, underdamped (ζ<1) oscillatory decay. Natural frequency ω₀ and damping define the transient shape."
        }
      }
    }
  },

  {
    name = "AC Steady-State Analysis",
    sub = {
      {
        name = "Sinusoids",
        body = {
          "A sinusoidal source is v(t) = V_m·sin(ωt + φ). Key parameters are amplitude V_m, angular frequency ω = 2πf, and phase φ. Sinusoids are the basis of AC analysis because any periodic waveform can be Fourier-decomposed into sinusoids."
        }
      },
      {
        name = "Phasor Analysis",
        body = {
          "Represents sinusoids as complex numbers: Ṽ = V_rms∠φ. Differentiation becomes multiplication by jω, integration by 1/(jω). Phasor techniques convert differential equations to algebraic ones, vastly simplifying AC circuit analysis."
        }
      },
      {
        name = "Impedance and Admittance",
        body = {
          "Impedance Z = R + jX combines resistance and reactance into a complex quantity. Admittance Y = 1/Z = G + jB combines conductance and susceptance. You use Z and Y in Ohm’s Law form Ṽ = Ĩ·Z or Ĩ = Ṽ·Y for AC circuits."
        }
      },
      {
        name = "AC Circuit Analysis",
        body = {
          "Apply KVL/KCL, nodal/mesh analysis, source transformations, Thevenin/Norton and superposition in the phasor domain using impedances. Solve for phasor voltages and currents, then convert back to time domain with inverse phasor transformation."
        }
      }
    }
  },

  {
    name = "Steady-State Power Analysis",
    sub = {
      {
        name = "Instantaneous Power",
        body = {
          "p(t) = v(t)·i(t). For sinusoids, p(t) varies at twice the supply frequency and includes both real and reactive components. Instantaneous power analysis reveals energy exchange within the circuit over time."
        }
      },
      {
        name = "Active and Reactive Power",
        body = {
          "Active (real) power P = V_rms·I_rms·cosφ is the average power consumed. Reactive power Q = V_rms·I_rms·sinφ oscillates between source and reactive elements. P does work; Q sustains energy storage in L and C."
        }
      },
      {
        name = "Complex Power",
        body = {
          "S = P + jQ = Ṽ·Ĩ*, where Ṽ and Ĩ are phasors and * denotes the complex conjugate. Complex power succinctly captures both active and reactive components in a single complex quantity."
        }
      },
      {
        name = "Power Factor and PF Correction",
        body = {
          "Power factor PF = cosφ = P/|S| measures efficiency. A PF < 1 means reactive power is present. Correction adds capacitors or inductors to shift φ toward zero, reducing line losses and improving voltage regulation."
        }
      }
    }
  },

  {
    name = "Magnetically Coupled Networks",
    sub = {
      {
        name = "Mutual Inductance",
        body = {
          "M describes coupling between two inductors: v₁ = L₁ di₁/dt + M di₂/dt, and vice versa. The coupling coefficient k = M/√(L₁L₂) (0 ≤ k ≤ 1) quantifies how strongly the inductors interact."
        }
      },
      {
        name = "Ideal Transformers",
        body = {
          "An ideal transformer has N₁/N₂ = V₁/V₂ = I₂/I₁ and zero losses. Referred impedances scale by the square of the turns ratio. Transformers enable voltage level shifting and isolation in power and signal circuits."
        }
      },
      {
        name = "Energy Analysis",
        body = {
          "Total magnetic energy in coupled inductors: W = ½L₁i₁² + ½L₂i₂² + Mi₁i₂. Energy methods help derive equivalent circuits and analyze transient behavior in transformer and coupled-coil systems."
        }
      }
    }
  },

  {
    name = "Poly-Phase Circuits",
    sub = {
      {
        name = "Three-Phase Circuits",
        body = {
          "Three sinusoidal sources of equal magnitude and 120° phase shift. Can be connected in wye (Y) or delta (Δ) configurations. Balanced systems simplify analysis to a single phase multiplied by three."
        }
      },
      {
        name = "Power Relationships",
        body = {
          "Total three-phase power P_total = √3·V_line·I_line·cosφ for balanced loads. Reactive and complex power scale similarly. These formulas are essential for power transmission and distribution calculations."
        }
      },
      {
        name = "Power Factor Correction",
        body = {
          "In three-phase systems, PF correction adds delta- or wye-connected capacitors to offset inductive loads, improving overall efficiency and reducing current drawn from the supply."
        }
      }
    }
  },

  {
    name = "Variable-Frequency Network Performance",
    sub = {
      {
        name = "Variable Frequency-Response Analysis",
        body = {
          "Examines how network gain and phase shift vary with frequency. Bode plots (magnitude and phase vs. log ω) reveal bandwidth, resonant peaks, and stability margins."
        }
      },
      {
        name = "Transfer Function",
        body = {
          "H(s) = V_out(s)/V_in(s) describes system behavior in the s-domain. By substituting s = jω, you get the frequency response. Poles and zeros of H(s) dictate stability and frequency characteristics."
        }
      },
      {
        name = "Resonant Circuits",
        body = {
          "Series resonance occurs when X_L = X_C, yielding minimum impedance and maximum current. Parallel resonance yields maximum impedance. Resonant frequency ω₀ = 1/√(LC). Q-factor measures sharpness of the peak."
        }
      },
      {
        name = "Filter Networks",
        body = {
          "Low-pass, high-pass, band-pass, and band-stop filters shape frequency content. Filter order and topology (Butterworth, Chebyshev, Bessel) determine roll-off rate and passband ripple."
        }
      }
    }
  },

  {
    name = "The Laplace Transform",
    sub = {
      {
        name = "Definition of the Laplace Transform",
        body = {
          "L{f(t)} = ∫₀^∞ f(t)e^(-st) dt. Converts time-domain functions into the s-domain, turning differential equations into algebraic ones for easier analysis."
        }
      },
      {
        name = "Transform Pairs",
        body = {
          "Common pairs: L{1} = 1/s, L{tⁿ} = n!/s^(n+1), L{e^(at)} = 1/(s-a), L{sin(ωt)} = ω/(s²+ω²), L{cos(ωt)} = s/(s²+ω²). These tables speed up inverse transforms and circuit analysis."
        }
      },
      {
        name = "Properties of the Laplace Transform",
        body = {
          "Linearity, time-shifting, frequency-shifting, differentiation (L{f'(t)} = sF(s) - f(0⁻)), integration, initial and final value theorems. Properties let you manipulate transforms algebraically."
        }
      },
      {
        name = "Performing the Inverse Laplace Transform",
        body = {
          "Use partial fraction expansion, convolution, and transform tables to recover f(t) from F(s). The Bromwich integral is the formal contour integral definition but is rarely used in practice."
        }
      },
      {
        name = "Convolution Integral",
        body = {
          "f(t) * g(t) = ∫₀^t f(τ)g(t-τ) dτ in time domain ↔ multiplication F(s)G(s) in s-domain. Convolution describes how systems with impulse response g(t) respond to arbitrary inputs f(t)."
        }
      },
      {
        name = "Initial-Value and Final-Value Theorems",
        body = {
          "Initial-value: f(0⁺) = lim_{s→∞} sF(s). Final-value: f(∞) = lim_{s→0} sF(s), provided poles of sF(s) lie in left half-plane. These theorems let you read boundary values directly from F(s)."
        }
      },
      {
        name = "Solving Differential Equations with Laplace Transforms",
        body = {
          "Take Laplace of both sides, apply algebraic manipulations to solve for F(s), then perform inverse transform to get f(t). This method handles initial conditions automatically and avoids solving higher-order ODEs by repeated integration."
        }
      }
    }
  }
}


-- Build UI
NotesMenu = WScreen(); NotesList=sList(); NotesMenu:appendWidget(NotesList,5,30); NotesList:setSize(-10,-40)
function NotesMenu:pushed() NotesList.items={}; for i,c in ipairs(NotesCategories) do NotesList.items[i]=c.name end; NotesList:reset(); NotesList:giveFocus() end
NotesList.action = function(_,i) push_screen(NotesSubMenu,i) end

NotesSubMenu=WScreen(); NotesSubList=sList(); NotesSubMenu:appendWidget(NotesSubList,5,30); NotesSubList:setSize(-10,-40)
function NotesSubMenu:pushed(ci)
    self.catIdx = ci  -- store main category index
    NotesSubList.items = {}
    for i, s in ipairs(NotesCategories[ci].sub) do
        NotesSubList.items[i] = s.name
    end
    NotesSubList:reset()
    NotesSubList:giveFocus()
end
NotesSubList.action = function(_,si) push_screen(NotesView, NotesSubMenu.catIdx or 1, si) end
NotesSubMenu.escapeKey = function() pop_screen() end

NotesView=WScreen()
function NotesView:pushed(ci,si) self.cat, self.sub = ci, si end
-- Modified NotesView:paint with text wrapping
function NotesView:paint(gc)
    local n = NotesCategories[self.cat].sub[self.sub]
    gc:setFont("sansserif","b",12)  -- reduced title font size
    gc:drawString(n.name, 10, 10, "top")
    gc:setFont("sansserif","r",10)  -- reduced body text font size
    local y = 30
    local maxWidth = platform.window:width() - 20
    local function wrapText(text)
        local lines = {}
        for word in string.gmatch(text, "%S+") do
            if #lines == 0 then
                table.insert(lines, word)
            else
                local current = lines[#lines]
                if gc:getStringWidth(current.." "..word) <= maxWidth then
                    lines[#lines] = current.." "..word
                else
                    table.insert(lines, word)
                end
            end
        end
        return lines
    end
    for _, paragraph in ipairs(n.body) do
        local wrapped = wrapText(paragraph)
        for _, line in ipairs(wrapped) do
            gc:drawString(line, 10, y, "top")
            y = y + 18
        end
        y = y + 6  -- extra space between paragraphs
    end
end
NotesView.escapeKey = function() pop_screen() end

-- Helper function to get the focused widget
function getFocusedWidget()
    local top = Screens[#Screens]
    if top and top.widgets then
        for _, w in ipairs(top.widgets) do
            if w.hasFocus then return w end
        end
    end
end

-- New arrow key events
function on.arrowUp() local w = getFocusedWidget() if w and w.arrowKey then w:arrowKey("up") end end
function on.arrowDown() local w = getFocusedWidget() if w and w.arrowKey then w:arrowKey("down") end end

-- Launch
push_screen(NotesMenu)
