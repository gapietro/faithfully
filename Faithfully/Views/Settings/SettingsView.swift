import SwiftUI
import SwiftData

struct SettingsView: View {
    let vm: SettingsViewModel

    var body: some View {
        NavigationStack {
                List {
                    Section("Bible Translation") {
                        Picker("Translation", selection: Binding(
                            get: { vm.translation },
                            set: { vm.updateTranslation($0) }
                        )) {
                            ForEach(BibleTranslation.allCases) { translation in
                                Text(translation.displayName).tag(translation)
                            }
                        }
                        .accessibilityIdentifier("translationPicker")
                    }

                    Section("Notifications") {
                        Toggle("Morning Challenge", isOn: Binding(
                            get: { vm.morningEnabled },
                            set: { vm.toggleMorningNotifications($0) }
                        ))
                        .accessibilityIdentifier("morningToggle")

                        DatePicker("Morning Time", selection: Binding(
                            get: { vm.morningTime },
                            set: { vm.updateMorningTime($0) }
                        ), displayedComponents: .hourAndMinute)
                        .disabled(!vm.morningEnabled)
                        .accessibilityIdentifier("morningTimePicker")

                        Toggle("Evening Reminder", isOn: Binding(
                            get: { vm.eveningEnabled },
                            set: { vm.toggleEveningReminders($0) }
                        ))
                        .accessibilityIdentifier("eveningToggle")

                        DatePicker("Evening Time", selection: Binding(
                            get: { vm.eveningTime },
                            set: { vm.updateEveningTime($0) }
                        ), displayedComponents: .hourAndMinute)
                        .disabled(!vm.eveningEnabled)
                        .accessibilityIdentifier("eveningTimePicker")

                        Toggle("Streak Warnings", isOn: Binding(
                            get: { vm.streakWarningsEnabled },
                            set: { vm.toggleStreakWarnings($0) }
                        ))
                        .accessibilityIdentifier("streakToggle")

                        Toggle("Badge Celebrations", isOn: Binding(
                            get: { vm.badgeNotificationsEnabled },
                            set: { vm.toggleBadgeNotifications($0) }
                        ))
                        .accessibilityIdentifier("badgeToggle")
                    }

                    Section("Appearance") {
                        Picker("Dark Mode", selection: Binding(
                            get: { vm.darkMode },
                            set: { vm.updateDarkMode($0) }
                        )) {
                            Text("System").tag(DarkModePreference.system)
                            Text("Light").tag(DarkModePreference.light)
                            Text("Dark").tag(DarkModePreference.dark)
                        }
                        .accessibilityIdentifier("darkModePicker")
                    }

                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text(AppInfo.current())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("versionRow")

                        Link("Privacy Policy", destination: AppInfo.privacyPolicyURL)
                            .accessibilityIdentifier("privacyPolicyLink")

                        Text("No account, no ads, no tracking. Everything you do in Faithfully stays on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("privacyBlurb")

                        Text("Scripture quotations from the World English Bible (public domain) and the King James Version (public domain).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("scriptureAttribution")
                    }
                }
                .navigationTitle("Settings")
        }
    }
}
