import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "output"]
  static values = { name: String }

  greet() {
    this.outputTarget.textContent = `Hello, ${this.nameValue || this.nameTarget.value}!`
  }
}