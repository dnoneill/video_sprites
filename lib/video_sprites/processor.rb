module VideoSprites
  class Processor
    def initialize(input_file, output_directory, options=nil)
      @input_file = input_file
      @output_directory = output_directory
      FileUtils.mkdir_p @output_directory unless File.exist? @output_directory
      @options = options || default_options
    end

    def process
      create_temporary_directory
      create_images
      create_sprites
      create_webvtt
      clean_temporary_directory
    end

    def create_temporary_directory
      @temporary_directory = Dir.mktmpdir
      puts @temporary_directory
    end

    def create_images
      # run ffmpeg command
      `#{ffmpeg_cmd}`
    end

    def create_sprites
      # determine how many images go in each sprite
      all_images.each_slice(images_per_sprite).with_index do |(*sprite_slice), index|
        cmd = montage_cmd(sprite_slice, index)
        # puts cmd
        `#{cmd}`
      end
    end

    def create_webvtt
      @webvtt = "WEBVTT\n\nNOTE This file was automatically generated by https://github.com/jronallo/video_sprites\n\n"
      start = 0
      total = 0
      sprite_count.times do |sprite_index|
        sprite_filename_base = File.basename sprite_filename(sprite_index)
        puts sprite_filename_base
        @options[:group].times do |group_index|
          next if total >= all_images.length
          cue_start = start
          cue_end = start + @options[:seconds]
          x = ((group_index % @options[:columns]) * @options[:width])
          y = (group_index.to_f / @options[:columns].to_f).floor * processed_height

          fractional_start = start == 0 ? "000" : "001"
          cue_times = "#{formatted_time(cue_start)}.#{fractional_start} --> #{formatted_time(cue_end)}.000\n"
          puts cue_times
          cue_text = "#{sprite_filename_base}#xywh=#{x},#{y},#{@options[:width]},#{processed_height}\n\n"
          @webvtt += cue_times
          @webvtt += cue_text
          start = cue_end
          total += 1
        end
      end
      File.open(webvtt_output_filename, 'w') do |fh|
        fh.puts @webvtt
      end
    end

    def ffmpeg_cmd
      %Q|ffmpeg -i "#{@input_file}" -vf fps=1/#{@options[:seconds]} #{thumbnail_image_path} |
    end

    def montage_cmd(sprite_slice, index)
      image_files = sprite_slice.join(' ')
      %Q|montage #{image_files} -tile #{@options[:columns]}x -geometry #{@options[:width]}x #{sprite_filename(index)}|
    end

    def thumbnail_image_path
      File.join @temporary_directory, 'img-%05d.jpg'
    end

    def sprite_filename(index)
      File.join @output_directory, "#{basename}-sprite-#{padded_index(index)}.jpg"
    end

    def webvtt_output_filename
      File.join @output_directory, "#{basename}.vtt"
    end

    def padded_index(index)
      (index + 1).to_s.rjust(5, "0")
    end

    def default_options
      {
        seconds: 10,
        width:   200,
        columns: 5,
        group:   20
      }
    end

    def all_images
      if @all_images
        @all_images
      else
        images = Dir[all_images_glob]
        images.pop
        @all_images = images
      end
    end

    def all_images_glob
      File.join @temporary_directory, '*'
    end

    def first_jpeg
      all_images.first
    end

    def sprite_count
      (all_images.length.to_f / @options[:group]).ceil
    end

    def images_per_sprite
      @options[:group]
    end

    # TODO: make basename configurable
    def basename
      "video"
    end

    def original_height
      `identify -format "%h" -ping "#{first_jpeg}"`.to_f
    end

    def original_width
      `identify -format "%w" -ping "#{first_jpeg}"`.to_f
    end

    def processed_height
      (original_height.to_f / original_width.to_f * @options[:width]).to_i
    end

    def formatted_time(total_seconds)
      seconds = total_seconds % 60
      minutes = (total_seconds / 60) % 60
      hours = total_seconds / (60 * 60)

      # TODO: format start times to start at .0001
      format("%02d:%02d:%02d", hours, minutes, seconds)
    end

    def clean_temporary_directory
      FileUtils.rm_rf @temporary_directory
    end

  end
end
