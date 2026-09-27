// Navigation and explicit submit outcomes can move focus. Live validation and
// record selection never steal focus from ongoing work.
export const WorkbenchAccessibility = {
  mounted() {
    this.section = this.el.dataset.section
    this.node = this.el.dataset.node
    this.handleEvent("workbench:focus", ({selector}) => {
      requestAnimationFrame(() => this.el.querySelector(selector)?.focus())
    })
  },
  updated() {
    if (this.section !== this.el.dataset.section) {
      this.section = this.el.dataset.section
      this.el.querySelector("#catalogue-heading")?.focus()
    } else if (this.node !== this.el.dataset.node) {
      this.el.querySelector("#component-heading")?.focus()
    }
    this.node = this.el.dataset.node
  },
}
