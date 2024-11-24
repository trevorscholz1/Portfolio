# GolfScorecard class
class GolfScorecard
    attr_reader :player_name, :course_name, :holes
  
    def initialize(player_name, course_name)
      @player_name = player_name
      @course_name = course_name
      @holes = Array.new(18, 0)
    end
  
    def input_score(hole_number, score)
      @holes[hole_number - 1] = score
    end
  
    def total_score
      @holes.sum
    end
  
    def print_scorecard
      puts "Player: #{@player_name}"
      puts "Course: #{@course_name}"
      puts "Hole\tScore"
      @holes.each_with_index do |score, index|
        puts "#{index + 1}\t#{score}"
      end
      puts "Total Score: #{total_score}"
    end
  end

  scorecard = GolfScorecard.new("Trevor Scholz", "Whitney Farms Golf Club")

  (1..18).each do |hole|
    print "Enter score for hole #{hole}: "
    score = gets.chomp.to_i
    scorecard.input_score(hole, score)
  end
  
  scorecard.print_scorecard
