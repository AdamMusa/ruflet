# Rocky Mountain Ruby 2026 CFP - Ruflet

Submission link: https://sessionize.com/rocky-mountain-ruby-2026/

Conference: Rocky Mountain Ruby 2026
Location: eTown Hall, Boulder, Colorado, United States
Dates: September 28-29, 2026
CFP closes: June 30, 2026 at 11:59 PM MDT
Format: 30-45 minute in-person talk, English

## Primary Proposal

### Title

Ruby Interfaces Beyond the Browser: Building Ruflet

### Elevator Pitch

Ruflet is a Ruby port of Flet that lets Rubyists build web, desktop, and mobile apps with Ruby. This talk is the story of turning that idea into a working runtime: a Ruby DSL, a WebSocket protocol layer, Rails integration, generated UI controls, and Flutter-backed clients that can run the same Ruby app across platforms.

### Abstract

Ruby has always been a language for people who want to build quickly without feeling like the tools are fighting them. But when a Ruby app needs to become a polished desktop or mobile experience, the path often gets awkward: keep Rails in the browser, switch stacks entirely, or maintain a separate frontend that drifts away from the Ruby codebase.

Ruflet explores another path. It brings the Flet style of UI programming to Ruby, so a developer can write a Ruby app like:

```ruby
Ruflet.run do |page|
  page.add(
    text("Hello from Ruby"),
    floating_action_button: fab(on_click: -> { page.update(...) })
  )
end
```

Behind that small example is a larger set of design problems: translating Ruby objects into a UI protocol, keeping state updates predictable over WebSockets, mapping Flutter controls into Ruby classes, supporting Rails apps without making Rails developers abandon their own conventions, and packaging clients for web, desktop, and mobile.

This talk walks through the practical architecture of Ruflet and the tradeoffs behind it. I will show how the project is split into `ruflet`, `ruflet_core`, `ruflet_server`, and `ruflet_rails`; how the runtime sends UI updates to a Flutter client; how the Rails generator mounts Ruflet views into an existing app; and where the project still has rough edges, including control parity, service APIs, and production ergonomics.

The goal is not to convince everyone that every Ruby app needs a native client. It is to share a real experiment in making Ruby feel useful in more places, and to give Rubyists concrete ideas for building protocol-driven tools, DSLs, and cross-platform interfaces without losing the clarity that makes Ruby fun.

### Audience Takeaways

- How to design a Ruby DSL that maps cleanly onto a cross-platform UI runtime.
- How a WebSocket-driven UI protocol can keep Ruby code in charge while a Flutter client renders the interface.
- What changes when the same Ruby UI needs to work in plain Ruby scripts and inside Rails.
- The practical costs of chasing parity with an existing ecosystem like Flet.
- Lessons from building developer tools that try to preserve Ruby's small-team speed.

### Outline

1. Why Ruflet exists: the gap between Ruby productivity and cross-platform UI.
2. The smallest useful Ruflet app: `Ruflet.run`, controls, events, and page updates.
3. Runtime architecture: Ruby control tree, wire codec, WebSocket server, Flutter client.
4. Rails integration: install generator, mounted route, Rails-hosted web builds, resource scaffolds, form helpers.
5. What broke or got weird: event mapping, control parity, services, packaging, and mobile workflow.
6. What this means for Rubyists: protocol-first tools, app-shaped gems, and building ambitious things with small teams.

### Notes For Reviewers

Ruflet is a real open source project and gem ecosystem, not a slide-only prototype. The talk will include code and architecture diagrams, but the tone is practical and honest: what worked, what still needs work, and what other Ruby developers can reuse from the experience even if they never use Ruflet itself.

This fits Rocky Mountain Ruby because it is about Ruby craft, community tooling, and helping Ruby developers build outside the usual Rails-only box. It is technical, but accessible to intermediate Rubyists.

## Alternate Proposal

### Title

The Boring Parts of Building an Ambitious Ruby Gem

### Abstract

Ruflet started with a fun idea: build web, desktop, and mobile apps in Ruby by porting Flet's programming model into the Ruby ecosystem. The surprising work was not only the UI layer. It was the boring parts: package boundaries, generators, release assets, protocol tests, examples, docs, versioning, and Rails integration that does not feel like a foreign object inside a Rails app.

This talk uses Ruflet as a case study in turning an ambitious Ruby idea into something other developers can actually install, run, and debug. We will cover the project split across `ruflet`, `ruflet_core`, `ruflet_server`, and `ruflet_rails`; the CLI shape; the Rails generators; the update/build flow for prebuilt clients; and the documentation choices that made the tool easier to try.

The audience will leave with a practical checklist for shipping Ruby tools that feel friendly from the first `gem install` through the first real bug report.

### Audience Takeaways

- How to split a Ruby tool into gems without making installation confusing.
- How generators can make a new runtime feel native inside Rails.
- How examples and docs can carry architecture decisions.
- How to make release assets and update commands part of the developer experience.
- How to keep an experimental Ruby project approachable while the internals are still moving.

## Speaker Bio Placeholder

Adam Musa is the creator of Ruflet, a Ruby port of Flet for building web, desktop, and mobile apps in Ruby. He works across Ruby, Rails, Flutter, and developer tooling, with a focus on making ambitious app development feel accessible to small teams and independent builders.

## Missing Before Submission

- Speaker email
- Speaker location
- Speaker photo
- Short social/profile links
- Confirmation that the speaker can attend in person in Boulder on September 28-29, 2026
- Whether travel/accommodation support is needed
