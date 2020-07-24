
module DeploymentMethod
  module Util
    module OutputDiagnostic
      def self.replace_matches(matches, str)
        result = str.clone

        (1..matches.length - 1).each do |index|
          result = result.gsub("[[#{index}]]", matches[index])
        end

        result
      end

      def self.analyze(name_entity, log)
        return "" unless log

        relative_filename = "lib/deployment_method/util/output_diagnostic_rules/" \
                            "#{name_entity}.json"
        rules = JSON.parse(IO.read(Rails.root.join(relative_filename)))

        result = ""

        rules.each do |rule|
          matches = Regexp.new(rule['input']).match(log)
          next unless matches

          result << "\n\n-------\n"
          result << "Detected: #{rule['input']}\n"
          result << "Explanation: " \
                    "#{OutputDiagnostic.replace_matches(matches, rule['explanation'])}\n"
          result << "*To fix*: " \
                    "#{OutputDiagnostic.replace_matches(matches, rule['action_to_take'])}\n"
          result << "-------\n\n"
        end

        result
      rescue StandardError => e
        Ex::Logger.info(e, "Issue analyzing output diagnostic #{name_entity}")
        ""
      end
    end
  end
end
