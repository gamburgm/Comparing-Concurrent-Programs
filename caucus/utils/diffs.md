### Syndicate v. The World
1. The dataspace eliminates the need for configuration (e.g. don't need to wait for other actors/threads to send certain information to a manager, it just exists in the dataspace)
2. Facets abstract away control flow
3. Syndicate makes it easier to manage receiving the same type of message across different states of the same actor
4. State management is tougher elsewhere: `valid voters` are hard to manage outside of syndicate, because you need to separate initial valid voters (setup?) from the set you need to filter with
  1. In defense of 'The World', in the dataspace world, you need to keep valid voter information around for longer than it's necessary, sometimes, e.g. in 'The World' you can just pass a shorter length of voters out to the next state rather than keeping a list of valid voters yourself

### Syndicate v. Channels
1. Synchronization occurs via channel-passing, so don't need to color everything w/region in the channels version

### Actors v. Channels
1. Don't have a dedicated channel for each conversation, just have a mailbox
