require 'gosu'

TOP_COLOR = Gosu::Color.new(0xFFFFFFFF)
BOTTOM_COLOR = Gosu::Color.new(0xFFFFFFFF)

# Define ZOrder for layering elements
module ZOrder
  BACKGROUND, UI, TEXT = *0..2
end

class QuizGame < Gosu::Window
  def initialize
    super 800, 600
    self.caption = "Trivia Quiz Game"

    @button_click_sound = Gosu::Sample.new("sound/b.wav")
    @background_music = Gosu::Song.new("sound/quiz.mp3")
    @correct = Gosu::Song.new("sound/correct.wav")
    @wrong = Gosu::Song.new("sound/wrong.mp3")
    @font = Gosu::Font.new(30)
    @background_image = Gosu::Image.new("images/background.png")
    @question_background_image = Gosu::Image.new("images/question.png")
    @start_button_image = Gosu::Image.new("images/start.png")
    @retry_button_image = Gosu::Image.new("images/retry.png")
    
    reset_game_variables
  end
# after reset
  def reset_game_variables
    @instructions_displayed = false
    @game_started = false
    @game_ended = false
    @quiz_selection_displayed = false
    @creating_quiz = false
    @timer = 10
    @instructions_timer = 5
    @score = 0
    @questions = []
    @current_question = 0
    @selected_quiz = nil
  end

# loads quizzes
  def load_quiz(file_name)
    questions = []
    
    begin
      file = File.open(file_name, 'r')
      line = file.gets   # Read the first line
  
      while line
        parts = line.chomp.split(';')
        question_text = parts[0]
        answers = parts[1..4]
        correct_answer_idx = parts[5].to_i
        questions << { question: question_text, answers: answers, correct_answer_idx: correct_answer_idx }
  
        line = file.gets  # Read the next line
      end
  
      file.close 
    end
    return questions
  end

  def create_quiz_in_terminal
    puts "\n=== Create New Quiz ==="
    puts "Enter quiz filename (e.g., myquiz.txt):"
    filename = gets.chomp
  
    # Ensure filename is not empty
    while filename.empty?
      puts "Filename cannot be empty. Please enter a valid filename:"
      filename = gets.chomp
    end
  
    questions = []
    puts "\nHow many questions do you want to add?"
    num_questions = gets.chomp.to_i
  
    num_questions.times do |i|
      puts "\nQuestion #{i + 1}:"
  
      # Input validation for the question
      question = ""
      while question.strip.empty?
        puts "Enter the question:"
        question = gets.chomp
        puts "Question cannot be empty. Please enter a valid question." if question.strip.empty?
      end
  
      # Input validation for the answer options
      answers = []
      4.times do |j|
        answer = ""
        while answer.strip.empty?
          puts "Enter answer option #{j + 1}:"
          answer = gets.chomp
          puts "Answer option cannot be empty. Please enter a valid answer." if answer.strip.empty?
        end
        answers << answer
      end
  
      # Input validation for the correct answer
      correct_answer = -1
      while correct_answer < 1 || correct_answer > 4
        puts "Enter the correct answer number (1-4):"
        correct_answer = gets.chomp.to_i
        if correct_answer < 1 || correct_answer > 4
          puts "Invalid choice. Please enter a number between 1 and 4."
        end
      end
  
      # Store the question data in the questions array
      questions << {
        question: question,
        answers: answers,
        correct_answer_idx: correct_answer - 1
      }
    end
  
    # Save the quiz to a file
    File.open(filename, 'w') do |file|
      questions.each do |q|
        line = "#{q[:question]};#{q[:answers].join(';')};#{q[:correct_answer_idx]}"
        file.puts(line)
      end
    end
  
    puts "\nQuiz created successfully!"
    puts "Your quiz has been saved as '#{filename}'"
    filename
  end
  
  
  

  def update
    if @instructions_displayed && @instructions_timer > 0
      @instructions_timer -= 1.0 / 60
      start_quiz if @instructions_timer <= 0
    elsif @game_started && @timer > 0
      @timer -= 1.0 / 60
    elsif @game_started && @timer <= 0
      next_question
    end
  end

  def draw
    draw_background
    if @quiz_selection_displayed
      draw_quiz_selection
    elsif @game_started
      draw_question_background
      draw_question
      draw_score
      draw_timer
    elsif @game_ended
      @background_music.stop
      draw_end_screen
    elsif @instructions_displayed
      draw_instructions
    else
      draw_start_screen
    end
  end

  def draw_background
    Gosu.draw_rect(0, 0, 800, 600, TOP_COLOR, ZOrder::BACKGROUND)
    @background_image.draw(0, 0, ZOrder::BACKGROUND)
  end

  def draw_start_screen
    @font.draw_text("Trivia Game", 250, 100, ZOrder::UI, 2.0, 2.0, Gosu::Color::BLACK)
    @start_button_image.draw(295, 320, ZOrder::UI)
  end

  def draw_quiz_selection
    @font.draw_text("Select a Quiz:", 250, 100, ZOrder::UI, 2.0, 2.0, Gosu::Color::BLACK)
    @font.draw_text("1. Math", 280, 200, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    @font.draw_text("2. English", 280, 250, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    @font.draw_text("3. Science", 280, 300, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    @font.draw_text("4. Random Quiz", 280, 350, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    @font.draw_text("5. Create New Quiz", 280, 400, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    if @custom_quiz_filename && File.exist?(@custom_quiz_filename)
      @font.draw_text("6. Play Custom Quiz", 280, 450, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    end
  end

  def load_random_quiz
    quiz_files = ['math.txt', 'english.txt', 'science.txt']
    quiz_files << @custom_quiz_filename if @custom_quiz_filename && File.exist?(@custom_quiz_filename)
    
    # Randomly select a quiz file
    selected_file = quiz_files.sample
    
    # Load questions from the selected file
    questions = load_quiz(selected_file)
    
    # Randomize the order of questions
    questions.shuffle!
    
    # Randomize the order of answers for each question
    questions.each do |question|
      correct_answer = question[:answers][question[:correct_answer_idx]]
      shuffled_answers = question[:answers].shuffle
      question[:correct_answer_idx] = shuffled_answers.index(correct_answer)
      question[:answers] = shuffled_answers
    end
    
    questions
  end

  def draw_instructions
    instructions = [
      "Instructions:",
      "1. Use keys 1 to 4 to answer.",
      "2. You have 10 seconds per question!",
      "3. Aim for a high score!"
    ]
    instructions.each_with_index do |line, index|
      @font.draw_text(line, 100, 200 + index * 50, ZOrder::TEXT, 1.0, 1.0, Gosu::Color::BLACK)
    end
  end

  def draw_question_background
    @question_background_image.draw(0, 0, ZOrder::BACKGROUND)
  end



  def draw_answer_button(answer, index)
    col = index % 2
    row = index / 2
    x_position = 70 + col * 375
    y_position = 300 + row * 100

    @font.draw_text("#{index + 1}. #{answer}", x_position + 10, y_position + 10, ZOrder::TEXT, 1.2, 1.2, Gosu::Color::WHITE)
  end

  def draw_score
    @font.draw_text("Score: #{@score}", 50, 500, ZOrder::UI, 1.5, 1.5, Gosu::Color::GREEN)
  end

  def draw_timer
    @font.draw_text("Time Left: #{(@timer).round}", 550, 20, ZOrder::UI, 1.5, 1.5, Gosu::Color::RED)
  end

  def draw_end_screen
    @font.draw_text("Game Over!", 250, 100, ZOrder::UI, 2.0, 2.0, Gosu::Color::BLACK)
    @font.draw_text("Your final score: #{@score}", 230, 200, ZOrder::UI, 1.5, 1.5, Gosu::Color::BLACK)
    @font.draw_text("Click to retry or press 'R'", 250, 250, ZOrder::UI, 1.0, 1.0, Gosu::Color::BLACK)
    @retry_button_image.draw(290, 300, ZOrder::UI)
  end

  def button_down(id)
    if id == Gosu::MsLeft
      if !@game_started && !@instructions_displayed && !@game_ended
        if start_button_clicked?(mouse_x, mouse_y )
          @button_click_sound.play
          show_quiz_selection
        end
      elsif @game_ended && retry_button_clicked?(mouse_x, mouse_y)
        @button_click_sound.play
        reset_and_restart
      end
    elsif @quiz_selection_displayed
      case id
      when Gosu::KB_1
        start_quiz_selection("math.txt")
      when Gosu::KB_2
        start_quiz_selection("english.txt")
      when Gosu::KB_3
        start_quiz_selection("science.txt")
      when Gosu::KB_4
        @questions = load_random_quiz
        @current_question = 0
        @quiz_selection_displayed = false
        @instructions_displayed = true
      when Gosu::KB_5
        filename = create_quiz_in_terminal
        @custom_quiz_filename = filename
        show_quiz_selection
      when Gosu::KB_6
        start_quiz_selection(@custom_quiz_filename) if @custom_quiz_filename && File.exist?(@custom_quiz_filename)
      end
    elsif id.between?(Gosu::KB_1, Gosu::KB_4) && @game_started
      check_answer(id - Gosu::KB_1)
    elsif id == Gosu::KB_R
      @button_click_sound.play
      reset_and_restart
    end
  end

    def draw_question
      return if @questions.empty? || @current_question >= @questions.size
      
      question = @questions[@current_question]
      
      # Wrap the question text
      wrapped_question = word_wrap(question[:question], 30) 
      
      # Draw each line of the wrapped question
      wrapped_question.each_with_index do |line, index|
        @font.draw_text(line, 220, 151 + index * 30, ZOrder::UI, 1.2, 1.2, Gosu::Color::WHITE)
      end
      
      # Draw answers
      question[:answers].each_with_index do |answer, index|
        draw_answer_button(answer, index)
      end
    end
    # to wrap the question
    def word_wrap(text, width)
      words = text.split(' ')
      lines = []
      line = ""
      
      words.each do |word|
        if (line + word).length > width
          lines << line.strip
          line = word + ' '
        else
          line += word + ' '
        end
      end
      
      lines << line.strip if line.length > 0
      lines
    end

    

  def start_button_clicked?(x, y)
    # Button drawn at (295, 320)
    x.between?(295, 295 + 200) && y.between?(320, 320 + 140)
  end
  
  def retry_button_clicked?(x, y)
    # Button drawn at (290, 300)
    x.between?(290, 290 + 200) && y.between?(300, 300 + 100)
  end

  def show_quiz_selection
    @quiz_selection_displayed = true
    @instructions_displayed = false
    @game_started = false
    @game_ended = false
  end

  def start_quiz_selection(file_name = nil)
    if file_name
      @selected_quiz = file_name
      begin
        if file_empty?(file_name)
          puts "Error: Quiz file is empty!"
          reset_game_variables
          show_quiz_selection
          return
        end
        @questions = load_quiz(file_name)
        @current_question = 0
        @quiz_selection_displayed = false
        @instructions_displayed = true
      rescue Errno::ENOENT
        puts "Error: Quiz file not found!"
        reset_game_variables
        show_quiz_selection
        return
      end
    end
  end

  def file_empty?(file_name)
    File.zero?(file_name)
  end

  def start_quiz
    @instructions_displayed = false
    @game_started = true
    @timer = 10
    @background_music.play(volume = 1)
  end

  def next_question
    @timer = 10
    @current_question += 1
    if @current_question >= @questions.size
      @game_ended = true
      @game_started = false
    end
  end

  def check_answer(answer_idx)
    if answer_idx == @questions[@current_question][:correct_answer_idx]
      @background_music.pause  # Pause background music
      @correct.play           # Play correct sound
      @score += 1
      sleep(0.4)               # Wait for sound to finish
      @correct.stop
      @background_music.play  # Resume background music
    else
      @background_music.pause  # Pause background music
      @wrong.play             # Play wrong sound
      sleep(0.4)               # Wait for sound to finish
      @wrong.stop
      @background_music.play  # Resume background music
    end
    next_question
  end
  
  def reset_and_restart
    reset_game_variables
    show_quiz_selection
  end
end

 QuizGame.new.show