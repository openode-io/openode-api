
module DeploymentMethod
  module Util
    module OutputDiagnostic
      def self.analyze(name_entity, log)
        return "" unless log

        relative_filename = "lib/deployment_method/util/output_diagnostic_rules/" \
                            "#{name_entity}.json"
        rules = JSON.parse(IO.read(Rails.root.join(relative_filename)))

        result = ""

        rules.each do |rule|
          next unless log.to_s.include?(rule['input'])

          result << "\n\n-------\n"
          result << "Detected: #{rule['input']}\n"
          result << "Explanation: #{rule['explanation']}\n"
          result << "*To fix*: #{rule['action_to_take']}\n"
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
