
#Author: Wissem Ben Marzouk

function parse_file(filename::String)
    # Open the file and read all lines
    if isfile(filename)
     file = open(filename)
     lines = readlines(file)
     
     # Initialize variables to store information
     n=0
     k = 0
     x = []
     y = []
     nbp = []
     capa = []
     ideal = []
     warehouse = (0, 0)
    
     # Parse each line
     for line in lines
        
        # Check if the line starts with "K"
        if startswith(line, "K")
            # Parse the number after "K" as the capacity of the trailer
            k = parse(Int64, split(line)[2])
        elseif startswith(line, "stations")
            # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "name")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "#")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "warehouse")
            # Parse the line as the warehouse coordinates
            coords = split(line)[2:3]
            warehouse = (parse(Int64, coords[1]), parse(Int64, coords[2]))
        else
            
            tab = split(line, " ")
            push!(x, parse(Int64, tab[2]))
            push!(y, parse(Int64, tab[3]))
            push!(nbp, parse(Int64, tab[4]))
            push!(capa, parse(Int64, tab[5]))
            push!(ideal, parse(Int64, tab[6]))
            
        end
     end
     n=size(x, 1)

     # Close the file
     close(file)

     # Return the parsed information
    
    end
     return n, k, warehouse, x, y, nbp, capa, ideal
end

function greedy_tour(n::Int64,d::Array{Int64,2},d_war::Vector{Int64})
   
    # start from a random station
    curr_pos=rand(1:n)
    tour = [curr_pos]

    # Repeat until all stations have been visited
    while length(tour) < n

        # Initialize the minimum distance to the maximum possible value
        min_dist = maximum(d)

        # Initialize the nearest station to 0
        nearest_station = 0

        # Loop through the unvisited stations
        for i in setdiff(1:n, tour)

            # If the distance is smaller than the current minimum distance, update the minimum distance and nearest station
            if d[curr_pos, i] < min_dist

                min_dist = d[curr_pos, i]
                nearest_station = i

            end
        end

        # Add the nearest station to the tour
        push!(tour, nearest_station)
        
        # Set the current position to the nearest station
        curr_pos = nearest_station
    end

    distance = d_war[tour[1]] + d_war[tour[end]] # distances from warehouse to first and last stations

    for i in 1:length(tour)-1

        distance += d[tour[i], tour[i+1]]

    end

    #println(distance)
    # Return the tour and total distance
    return tour ,distance
end

# Calculate the global imbalance given the current state of the stations
function calc_global_imbalance(nbp_work::Vector{Any},ideal::Vector{Any})

    #Initialize the total imbalance 
    imbalance = 0

    for i in 1:length(nbp_work)

        imbalance += abs(nbp_work[i] - ideal[i])

    end

    return imbalance
end

function perform_tour(tour::Vector{Int64},k::Int64, nbp_work::Vector{Any}, capa::Vector{Any},ideal::Vector{Any})

    # Copy the nbp variable to another variable 
    # so when we ran the code more than once we don't change the original nbp variable taken from the instance.
    nbp_cur=copy(nbp_work)

    # Initialize variables
    load = zeros(Int, length(nbp_work)+1)
    drop = zeros(Int, length(nbp_work)+1)

    # Randomise the load on the trailer at the warehouse
    load[1] = rand(0:k)

    
    # Iterate through each station on the tour
    for j in 2:length(nbp_work)+1

        # Calculate the imbalance at the current station
        imbalance = nbp_cur[tour[j-1]] - ideal[tour[j-1]]

        
        # If the station is too empty, unload bikes from the trailer then update load and nbp
        if imbalance < 0

            drop[j] = min(-imbalance, load[j-1])
           
            load[j] = load[j-1] - drop[j]
            
            nbp_cur[tour[j-1]] += drop[j]
            
        # If the station is too full, load bikes on the trailer then update load and nbp
        elseif imbalance > 0

            drop[j] = min(imbalance, k - load[j-1])
            
            load[j] = load[j-1] + drop[j]
            
            nbp_cur[tour[j-1]] -= drop[j]

            drop[j]=-drop[j]
           
        # If the station is balanced, do nothing
        else

            drop[j] = 0
            
            load[j] = load[j-1]
           
        end
        
        # We will not set conditions utilizing capa[i] because ideal[i] <= capa[i] 

    end
    
    return nbp_cur,drop,load
end

# main function

function kailxyv1(n::Int64,k::Int64, nbp_work::Vector{Any}, capa::Vector{Any}, 
    ideal::Vector{Any},x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})
    
   # calculate distances
   d ,d_war= distances(x,y,w)
   #set the weighting coefficient
   wight = n * maximum(d)

   # Initialize the current state
   curr_state = copy(nbp_work)
   curr_tour,curr_distance=greedy_tour(n,d, d_war)
   curr_cost = wight * calc_global_imbalance(curr_state, ideal) + curr_distance

   # Initialize the load and drop vectors 
   load = zeros(Int, length(nbp_work)+1)
   drop = zeros(Int, length(nbp_work)+1)

   # Set the iteration number for the kailxyv1 loop 
   num_iter = 10000

   # Initialize the best state ,cost, load and drop
   best_state = copy(curr_state)
   best_cost = curr_cost
   best_drop=copy(drop)
   best_load=copy(load)
   best_tour=curr_tour

   # Start a chronometer
   start = time()

   # Perform for a number of iterations
   for i in 1:num_iter

       # Perform a random tour and update the current state
       next_tour,next_distance=greedy_tour(n,d, d_war)
       next_sate,next_drop,next_load=perform_tour(next_tour,k,curr_state,capa,ideal)
       #println("le load est: ",next_load)
       #println("le drop est: ",next_drop)
       #get the next cost 
       next_cost = wight * calc_global_imbalance(next_sate, ideal) + next_distance
       #println("the iteration ",i," we have next cost :",next_cost)

           # If the new state is the best so far, update the best state and cost
            if  next_cost < best_cost
               best_state = copy(next_sate)
               best_cost = next_cost
               best_drop=copy(next_drop)
               best_load=copy(next_load)
               best_imba=calc_global_imbalance(best_state, ideal)
               d_best=best_cost-wight*best_imba
               println("Hey guess what! we found a local minima ( hope to escape it though ) at the iteration number ",i," with current imbalance of ",best_imba
               ," and current load 0 = ",best_load[1]," and current total distance of ",d_best)
               best_tour=next_tour
               #println("The best tour so far is ",best_tour,".")
           end
        
    end
       
       imb_final=calc_global_imbalance(best_state, ideal)
       d_final=best_cost-wight*imb_final
       
       finish = time()
       println(" ")
       println("We took ",finish-start," seconds to finish.")
       println(" ")
       println("We start our tour with load 0 = ",best_load[1],".")
       println(" ")
       
       for i in 1:n
        
        println("At step ",i," we go to station ",best_tour[i]," we drop ",best_drop[i+1], ". After the drop operation the trailer has ",best_load[i+1]," bikes.")
        println(" ")
       end
       println("The heuristic optimization resulted in an overall imbalance of ",imb_final,", and total distance of ",d_final,".")
       # Open the file and write the header
    file = open("tsdp_9_s500_k14_RSS.sol", "w")
    write(file, "tsdp_9_s500_k14\n")
    write(file, "imbalance $imb_final\n")
    write(file, "distance $d_final\n")
    best_loadv=best_load[1]
    write(file, "init_load $best_loadv\n")

    # Write the station header
    write(file, "stations\n")

    j=2
	for i in best_tour
		best_dropv=best_drop[j]
        write(file,"$i $best_dropv\n")
        j+=1        	
	end
	
    # Write the end marker
    write(file, "End\n")

    # Close the file
    close(file)
     
end