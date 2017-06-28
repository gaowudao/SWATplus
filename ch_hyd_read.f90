      subroutine ch_hyd_read
      
      use basin_module
      use input_file_module

      character (len=80) :: titldum, header
      integer :: eof, mon, i, imax

      eof = 0
      imax = 0
      
      inquire (file=in_cha%hyd, exist=i_exist)
      if (i_exist == 0 .or. in_cha%hyd == 'null') then
        allocate (ch_hyd(0:0))
      else   
      do
       open (105,file=in_cha%hyd)
       read (105,*,iostat=eof) titldum
       if (eof < 0) exit
       read (105,*,iostat=eof) header
       if (eof < 0) exit
        do while (eof == 0)
          read (105,*,iostat=eof) i
          if (eof < 0) exit
          imax = Max(imax,i)
        end do
        
      db_mx%ch_hyd = imax
      
      allocate (ch_hyd(0:imax))
      rewind (105)
      read (105,*) titldum
      read (105,*) header
    
       do ich = 1, db_mx%ch_hyd
         read (105,*,iostat=eof) i
         backspace (105)
         read (105,*,iostat=eof) k, ch_hyd(ich)
         if (eof < 0) exit
         
        ch_hyd(ich)%alpha_bnk = Exp(-ch_hyd(ich)%alpha_bnk)
        if (ch_hyd(ich)%s <= 0.) ch_hyd(ich)%s = .0001
        if (ch_hyd(ich)%n <= 0.01) ch_hyd(ich)%n = .01
        if (ch_hyd(ich)%n >= 0.70) ch_hyd(ich)%n = 0.70
        if (ch_hyd(ich)%l <= 0.) ch_hyd(ich)%l = .0010
        if (ch_hyd(ich)%wdr <= 0.) ch_hyd(ich)%wdr = 3.5
        if (ch_hyd(ich)%side <= 1.e-6) ch_hyd(ich)%side = 2.0
        
       end do
       close (105)
      exit
      enddo
      endif

      return    
      end subroutine ch_hyd_read