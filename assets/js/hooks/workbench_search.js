// LiveView preserves focused input values during patches. Clear the visible
// field after the server resets its query, then return keyboard focus to it.
export const WorkbenchSearch = {
  mounted() {
    this.handleEvent("workbench:clear-search", ({id}) => {
      if (id !== this.el.id) return
      const input = this.el.querySelector("input")
      if (input) {
        input.value = ""
        input.focus()
      }
    })
  },
}
