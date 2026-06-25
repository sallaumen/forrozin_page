const OnboardingTour = {
  mounted() {
    if (localStorage.getItem('tour_completed')) return
    this._timer = setTimeout(() => this.startTour(), 800)
  },
  destroyed() {
    if (this._timer) clearTimeout(this._timer)
    this.cleanup()
  },
  startTour() {
    const isMobile = window.innerWidth < 768
    this.steps = [
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(1)'
          : '#top-nav-desktop-primary-nav a:nth-child(1)',
        title: 'Aqui fica todo o acervo.',
        text: 'Uma wiki de forró roots construída pela comunidade. Explore os passos, sugira melhorias e contribua!',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(2)'
          : '#top-nav-desktop-primary-nav a:nth-child(2)',
        title: 'O mapa mostra como os passos se conectam.',
        text: 'Veja as entradas e saídas de cada passo. Você pode sugerir novas conexões ou criar sequências.',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(3)'
          : '#top-nav-desktop-primary-nav div:nth-child(3) a',
        title: 'Seu diário de treino.',
        text: 'Anote o que praticou, vincule passos e acompanhe sua evolução. Professores podem criar diários compartilhados com alunos.',
      },
      {
        selector: isMobile
          ? '[data-ui="bottom-nav"] li:nth-child(5)'
          : '#top-nav-desktop-primary-nav a:nth-child(4)',
        title: 'Sequências da comunidade.',
        text: 'Combinações de passos criadas pela galera. Você também pode criar e compartilhar as suas!',
      },
      {
        selector: '#collection-shell',
        title: 'Esse projeto é de todo mundo.',
        text: 'Tudo pode ser editado por você. Sugira passos, conexões e melhorias. Quanto mais gente contribui, melhor fica. Bom treino!',
      },
    ]
    this.currentStep = 0
    this.render()
  },
  render() {
    this.cleanup()
    if (this.currentStep >= this.steps.length) { this.finish(); return }
    const step = this.steps[this.currentStep]
    const total = this.steps.length
    const target = step.selector ? document.querySelector(step.selector) : null
    const isLast = this.currentStep === total - 1

    // Overlay with spotlight cutout
    const overlay = document.createElement('div')
    overlay.id = 'tour-overlay'
    overlay.style.cssText = 'position:fixed;inset:0;z-index:9998;'

    if (target) {
      const r = target.getBoundingClientRect()
      const p = 6, rd = 8, vw = window.innerWidth, vh = window.innerHeight
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
      svg.setAttribute('width', vw)
      svg.setAttribute('height', vh)
      svg.style.cssText = 'position:fixed;inset:0;'

      const mask = document.createElementNS('http://www.w3.org/2000/svg', 'mask')
      mask.id = 'tour-mask'
      const bg = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      bg.setAttribute('width', '100%'); bg.setAttribute('height', '100%'); bg.setAttribute('fill', 'white')
      const cut = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      cut.setAttribute('x', r.left - p); cut.setAttribute('y', r.top - p)
      cut.setAttribute('width', r.width + p*2); cut.setAttribute('height', r.height + p*2)
      cut.setAttribute('rx', rd); cut.setAttribute('fill', 'black')
      mask.append(bg, cut)

      const fill = document.createElementNS('http://www.w3.org/2000/svg', 'rect')
      fill.setAttribute('width', '100%'); fill.setAttribute('height', '100%')
      fill.setAttribute('fill', 'rgba(0,0,0,0.6)'); fill.setAttribute('mask', 'url(#tour-mask)')

      const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
      defs.appendChild(mask)
      svg.append(defs, fill)
      overlay.appendChild(svg)
    } else {
      const dim = document.createElement('div')
      dim.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.6);'
      overlay.appendChild(dim)
    }
    document.body.appendChild(overlay)

    // Tooltip (safe: all content is hardcoded strings, no user input)
    const tt = document.createElement('div')
    tt.id = 'tour-tooltip'
    Object.assign(tt.style, {
      position:'fixed', zIndex:'9999',
      background:'#faf8f4', border:'1px solid rgba(0,0,0,0.1)',
      borderRadius:'12px', padding:'20px 22px 16px',
      boxShadow:'0 20px 50px rgba(30,22,16,0.25)',
      maxWidth:'320px', width:'calc(100vw - 2rem)',
      fontFamily:"'Source Serif 4',Georgia,serif",
      animation:'slide-in-right 0.25s ease-out',
    })

    const counter = document.createElement('div')
    Object.assign(counter.style, {fontSize:'10px',color:'#9a8a78',fontWeight:'600',textTransform:'uppercase',letterSpacing:'0.15em',marginBottom:'8px'})
    counter.textContent = `${this.currentStep + 1} de ${total}`

    const title = document.createElement('div')
    Object.assign(title.style, {fontSize:'15px',fontWeight:'700',color:'#1a0e05',marginBottom:'6px',lineHeight:'1.3'})
    title.textContent = step.title

    const text = document.createElement('div')
    Object.assign(text.style, {fontSize:'13px',color:'#5c4a3a',lineHeight:'1.6',marginBottom:'16px'})
    text.textContent = step.text

    const btns = document.createElement('div')
    Object.assign(btns.style, {display:'flex',gap:'8px',justifyContent:'flex-end'})

    if (!isLast) {
      const skip = document.createElement('button')
      Object.assign(skip.style, {background:'transparent',border:'1px solid rgba(0,0,0,0.1)',borderRadius:'8px',padding:'8px 16px',fontSize:'12px',color:'#9a8a78',cursor:'pointer',fontFamily:'inherit'})
      skip.textContent = 'Pular'
      skip.addEventListener('click', () => this.finish())
      btns.appendChild(skip)
    }

    const next = document.createElement('button')
    Object.assign(next.style, {background:'#1a0e05',color:'#faf8f4',border:'none',borderRadius:'8px',padding:'8px 20px',fontSize:'12px',fontWeight:'600',cursor:'pointer',fontFamily:'inherit'})
    next.textContent = isLast ? 'Começar!' : 'Próximo'
    next.addEventListener('click', () => { this.currentStep++; this.render() })
    btns.appendChild(next)

    tt.append(counter, title, text, btns)
    document.body.appendChild(tt)

    // Position tooltip
    if (target) {
      const r = target.getBoundingClientRect()
      const ttRect = tt.getBoundingClientRect()
      if (window.innerWidth < 768 && r.top > window.innerHeight / 2) {
        tt.style.bottom = (window.innerHeight - r.top + 16) + 'px'
        tt.style.left = Math.max(16, Math.min(r.left, window.innerWidth - ttRect.width - 16)) + 'px'
      } else {
        tt.style.top = (r.bottom + 16) + 'px'
        tt.style.left = Math.max(16, Math.min(r.left, window.innerWidth - ttRect.width - 16)) + 'px'
      }
    } else {
      tt.style.top = '50%'; tt.style.left = '50%'; tt.style.transform = 'translate(-50%, -50%)'
    }

    overlay.addEventListener('click', (e) => {
      if (e.target.closest('#tour-tooltip')) return
      this.currentStep++; this.render()
    })
  },
  cleanup() {
    const o = document.getElementById('tour-overlay')
    const t = document.getElementById('tour-tooltip')
    if (o) o.remove()
    if (t) t.remove()
  },
  finish() {
    this.cleanup()
    localStorage.setItem('tour_completed', '1')
    localStorage.setItem('onboarding_seen', '1')
  }
}

export default OnboardingTour
